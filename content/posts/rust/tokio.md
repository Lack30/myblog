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