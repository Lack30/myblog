---
title: "Tokio 初尝试"
date: 2021-09-12T14:46:43+08:00
lastmod: 2021-09-12T14:46:43+08:00
draft: false
keywords: 
 - rust
 - tokio
description: ""
featuredImage: "https://raw.githubusercontent.com/xingyys/myblog/main/posts/images/rust-logo.png"
tags: 
 - rust
categories: 
 - 开发
author: "Lack"
---

## 简介
> Tokio is an asynchronous runtime for the Rust programming language. It provides the building blocks needed for writing networking applications. It gives the flexibility to target a wide range of systems, from large servers with dozens of cores to small embedded devices.

`Tokio` 是 `rust` 实现的异步库，提供一个异步运行时。它具有以下的特点:
- Fast: rust 本身就有 C 语言的性能，tokio 又建立在 async/await feature 上，使得非常快，特别在处理 I/O 问题上。
- Reliable: 得益于 rust 的特点。可靠性有保障。
- Easy: 借助 Rust 的 async/await 特性，编写异步应用程序的复杂性已大大降低。
- Flexible: Tokio 提供了多版本运行时。从多线程、窃取工作的运行时到轻量级的单线程运行时。

## 安装
在 `Cargo.toml` 的 `[dependencies]` 加入:
```toml
tokio = { version = "1", features = ["full"] }
```
在 `src/main.rs` 中添加代码:
```rust
use std::io::Result;

async fn hello() {
    println!("hello")
}

fn main() -> Result<()> {
    let rt = tokio::runtime::Runtime::new()?;
    rt.block_on(hello());

    Ok(())
}
```
`cargo run` 输出结果:
```bash
hello
```
rust 宏 `#[tokio::main]` 能将异步 `async fn main()` 转化成同步的 `fn main()`.例如:
```rust
#[tokio::main]
async fn main() {
    println!("hello");
}
```
可以转化为:
```rust
fn main() {
    let mut rt = tokio::runtime::Runtime::new().unwrap();
    rt.block_on(async {
        println!("hello");
    })
}
```

## 并发
```rust
use tokio::net::{TcpListener, TcpStream};

#[tokio::main]
async fn main() {
    let listener = TcpListener::bind("127.0.0.1:6379").await.unwrap();

    loop {
        let (socket, _) = listener.accept().await.unwrap();

        // 每次都新启动 task 处理 tcp 连接
        tokio::spawn(async move {
            process(socket).await;
        });
    }
}

async fn process(_: TcpStream) {}
```
`tokio` task 是一个异步绿色线程。使用 `tokio::spawn` 创建异步块，返回类型为 `JoinHandle`。使用 `.await` 获取返回值。
```rust
#[tokio::main]
async fn main() {
    let handle = tokio::spawn(async move {
        "return value"
    });

    let out = handle.await.unwrap();
    println!("GOT {}", out);
}
```
task 被 `tokio` 内部调度器使用， 请确认内部有事可做。同时它们会在不同线程将执行。

`tokio` 中的任务非常轻量级。它们只需要一次分配和 64 字节的内存。应用程序可以随意产生数千甚至数百万个任务。

### 'static
task 的类型是 `'static` 的，这意味着任务内部的变量不能存在外部引用
```rust
use tokio::task;

#[tokio::main]
async fn main() {
    let v = vec![1, 2, 3];

    // v 变量转移到 task 内部
    task::spawn(async move {
        println!("Here's a vec: {:?}", v);
    });
}
```

### Send
`tokio::spawn` 产生的任务必须实现 `Send`。这允许 `tokio` 运行时在线程之间移动任务，同时它们在 `.await` 处挂起。
```rust
use tokio::task::yield_now;
use std::rc::Rc;

#[tokio::main]
async fn main() {
    tokio::spawn(async {
        // The scope forces `rc` to drop before `.await`.
        {
            let rc = Rc::new("hello");
            println!("{}", rc);
        }

        // `rc` is no longer used. It is **not** persisted when
        // the task yields to the scheduler
        yield_now().await;
    });
}
```

## 共享状态
在 `tokio` 中有几种不同的方式来共享状态。
- 使用 Mutex 保护共享状态。
- 生成一个任务来管理状态并使用消息传递对其进行操作。

通常，对简单数据使用第一种方法，对需要异步工作的事物（例如 I/O 原语）使用第二种方法。

```rust
use std::{
    collections::HashMap,
    sync::{Arc, Mutex},
};
use tokio::net::{TcpListener, TcpStream};

#[tokio::main]
async fn main() {
    let listener = TcpListener::bind("127.0.0.1:6379").await.unwrap();

    println!("Listening");

    let db = Arc::new(Mutex::new(HashMap::new()));

    loop {
        let (socket, _) = listener.accept().await.unwrap();

        let db = db.clone();

        println!("Accepted");
        tokio::spawn(async move {
            process(socket, db).await;
        });
    }
}

async fn process(_: TcpStream, _db: Arc<Mutex<HashMap<i32, i32>>>) {}
```

> 注意，使用 std::sync::Mutex 而不是 tokio::sync::Mutex 来保护 HashMap。一个常见的错误是在异步代码中无条件地使用 tokio::sync::Mutex。异步互斥锁是在调用 .await 时锁定的互斥锁。

等待获取锁时，同步 mutex 将等待当前 `lock`。这反过来又会阻止其他任务的处理。但是，切换到 `tokio::sync::Mutex` 通常没有帮助，因为异步 mutex 在内部使用同步 mutex。根据经验，只要争用率保持在低位且未在 `.await` 中上锁，即可从异步 mutex 内使用同步 mutex 即可。此外，考虑使用 `parking_lot::Mutex` 作为 `std::sync::Mutex` 的更快的替代方法。

使用 `tokio` 异步 mutex。
```rust
use tokio::sync::Mutex;

async fn increment_and_do_stuff(mutex: &Mutex<i32>) {
    let mut lock = mutex.lock().await;
    *lock += 1;
}

#[tokio::main]
async fn main() {
    let m = Mutex::new(1);
    increment_and_do_stuff(&m).await;
    println!("GOT {:?}", m);
}
```

## Channels
