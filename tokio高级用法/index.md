# tokio 高级用法


[上一篇](http://xingyys.tech/tokio%E5%88%9D%E5%B0%9D%E8%AF%95/)了解了 `tokio` 的基本用法，接下来我们继续深入 `tokio` 的详细用法。

## 深入 async
rust 从 1.36 版本开始引入 `async/await` 作为支持异步相关的关键字。其内部是实现了 `std::future::Future` 这个特性。

### Future
`std::future::Future` 的定义如下:
```rust
use std::pin::Pin;
use std::task::{Context, Poll};

pub trait Future {
    type Output;

    fn poll(self: Pin<&mut Self>, cx: &mut Context)
        -> Poll<Self::Output>;
}
```
`Output` 表示 `Future` 输出结果的类型*T*。[pin](https://doc.rust-lang.org/std/pin/index.html) 是 rust 能够在异步函数中支持 borrows 关键。它能在内存中划定一片固定的区域。

`Future` 实际上就是一个状态机，通过 `Poll` 改变 `Future` 状态。

实现一个简单的 `Future`，具有以下功能:
- 等待一段时间
- 输出字符到标准输出
- Yield 一段字符串

```rust
use std::future::Future;
use std::pin::Pin;
use std::task::{Context, Poll};
use std::time::{Duration, Instant};

struct Delay {
    when: Instant,
}

impl Future for Delay {
    type Output = &'static str;

    fn poll(self: Pin<&mut Self>, cx: &mut Context<'_>)
        -> Poll<&'static str>
    {
        if Instant::now() >= self.when {
            println!("Hello world");
            Poll::Ready("done")
        } else {
            // Ignore this line for now.
            // 这个很重要
            cx.waker().wake_by_ref();
            Poll::Pending
        }
    }
}

#[tokio::main]
async fn main() {
    let when = Instant::now() + Duration::from_millis(10);
    let future = Delay { when };

    let out = future.await;
    assert_eq!(out, "done");
}
```
通过调用 `.await` 获取 `Future` 的结果。

### Poll
rust 里关于 `Poll` 的定义:
```rust
pub enum Poll<T> {
    /// Represents that a value is immediately ready.
    #[lang = "Ready"]
    #[stable(feature = "futures_api", since = "1.36.0")]
    Ready(#[stable(feature = "futures_api", since = "1.36.0")] T),

    /// Represents that a value is not ready yet.
    ///
    /// When a function returns `Pending`, the function *must* also
    /// ensure that the current task is scheduled to be awoken when
    /// progress can be made.
    #[lang = "Pending"]
    #[stable(feature = "futures_api", since = "1.36.0")]
    Pending,
}
```
`Poll::Ready(T)` 表示 `Future` 完成，`Poll::Pending` 表示 `Future` 正在执行，一段时间后会重新调用 `poll`。

### Waker

```rust
fn poll(self: Pin<&mut Self>, cx: &mut Context) -> Poll<Self::Output>;
```
poll 函数的 Context 类型参数中有个 waker() 函数，该函数会返回一个跟当前任务绑定的 Waker，这个 Waker 有一个 wake() 函数，调用这个函数就能够通知执行器，执行器会调度与该 Waker 关联的任务，让他继续执行。资源在他就绪的时候就会调用 wake() 通知执行器让他继续对这个任务调用 poll。

> 当一个 Future 返回 Poll::Pending 时，他要确保执行器能够在稍后的某个时间点收到通知，如果无法保证这点，该任务会无限的挂起导致无法运行。返回 Poll::Pending 之后没有调用 wake 发送通知是一个很常见的错误。

### 总结
总结起来 Rust 的 `Future` 有以下特点:
- Rust 的异步操作是需要调用者通过 Poll 去推进的惰性操作
- Waker 被传递给 Future ， Future将使用他来任务进行关联
- 当资源未就绪时会返回 Poll::Pending，这时任务的 Waker 会被其记录下来
- 当资源就绪时，会使用已记录的 Waker 来发出通知
- 执行器接收到通知后会将对应的任务调度执行
- 任务被再次 Poll，因为资源此时已就绪所以这次执行能够推进任务的状态

### 其他
```rust
use std::future::Future;
use std::pin::Pin;
use std::sync::{Arc, Mutex};
use std::task::{Context, Poll, Waker};
use std::thread;
use std::time::{Duration, Instant};

struct Delay {
    when: Instant,
    // This Some when we have spawned a thread, and None otherwise.
    waker: Option<Arc<Mutex<Waker>>>,
}

impl Future for Delay {
    type Output = ();

    fn poll(mut self: Pin<&mut Self>, cx: &mut Context<'_>) -> Poll<()> {
        // First, if this is the first time the future is called, spawn the
        // timer thread. If the timer thread is already running, ensure the
        // stored `Waker` matches the current task's waker.
        if let Some(waker) = &self.waker {
            let mut waker = waker.lock().unwrap();

            // Check if the stored waker matches the current task's waker.
            // This is necessary as the `Delay` future instance may move to
            // a different task between calls to `poll`. If this happens, the
            // waker contained by the given `Context` will differ and we
            // must update our stored waker to reflect this change.
            if !waker.will_wake(cx.waker()) {
                *waker = cx.waker().clone();
            }
        } else {
            let when = self.when;
            let waker = Arc::new(Mutex::new(cx.waker().clone()));
            self.waker = Some(waker.clone());

            // This is the first time `poll` is called, spawn the timer thread.
            thread::spawn(move || {
                let now = Instant::now();

                if now < when {
                    thread::sleep(when - now);
                }

                // The duration has elapsed. Notify the caller by invoking
                // the waker.
                let waker = waker.lock().unwrap();
                waker.wake_by_ref();
            });
        }

        // Once the waker is stored and the timer thread is started, it is
        // time to check if the delay has completed. This is done by
        // checking the current instant. If the duration has elapsed, then
        // the future has completed and `Poll::Ready` is returned.
        if Instant::now() >= self.when {
            Poll::Ready(())
        } else {
            // The duration has not elapsed, the future has not completed so
            // return `Poll::Pending`.
            //
            // The `Future` trait contract requires that when `Pending` is
            // returned, the future ensures that the given waker is signalled
            // once the future should be polled again. In our case, by
            // returning `Pending` here, we are promising that we will
            // invoke the given waker included in the `Context` argument
            // once the requested duration has elapsed. We ensure this by
            // spawning the timer thread above.
            //
            // If we forget to invoke the waker, the task will hang
            // indefinitely.
            Poll::Pending
        }
    }
}
```
在每次调用 Future::poll 时检查参数的 Waker 是否与之前保存的一致，如果一致则不需要做任何处理，否则的话则需要将保存的 Waker 替换为新的那个。

Waker 是 Rust 异步机制的基础，但通常我们并不需要深入到底层，可以通过 `async/await` 配合 `tokio::sync::Notify` 达到相同的结果:
```rust
use tokio::sync::Notify;
use std::sync::Arc;
use std::time::{Duration, Instant};
use std::thread;

async fn delay(dur: Duration) {
  let when = Instant::now() + dur;
  let notify = Arc::new(Notify::new());
  let notify2 = notify.clone();

  thread::spawn(move || {
    let now = Instant::now();

    if now < when {
      thread::sleep(when - now);
    }

    notify2.notify_one();
  });

  notify.notified().await;
}
```

## select!
`tokio::select!` 宏允许我们等待多个异步的任务，并在其中一个完成时返回。
```rust
use tokio::sync::oneshot;

#[tokio::main]
async fn main() {
    let (tx1, rx1) = oneshot::channel();
    let (tx2, rx2) = oneshot::channel();

    tokio::spawn(async move {
        let _ = tx1.send("one");
    });

    tokio::spawn(async move {
        let _ = tx2.send("two");
    });

    tokio::select! {
      val = rx1 => {
        println!("rx1 completed first with {:?}", val);
      }
      val = rx2 => {
        println!("rx2 completed first with {:?}", val);
      }
    }
}
```
`Future` 或其他的类型可以通过实现 Drop 来实现资源清理的操作，Tokio 的 `oneshot::Receiver` 通过实现 Drop 来给 Sender 发送关闭的通知，Sender 会在收到通知的时候可以通过 通过 Drop 其他的资源来清理进程内的信息。

### 内部实现
我们通过一段代码来了解 `Future` 实现:
```rust
use std::{
    future::Future,
    pin::Pin,
    task::{Context, Poll},
};

use tokio::sync::oneshot;

struct MySelect {
    rx1: oneshot::Receiver<&'static str>,
    rx2: oneshot::Receiver<&'static str>,
}

impl Future for MySelect {
    type Output = ();

    fn poll(mut self: Pin<&mut Self>, cx: &mut Context<'_>) -> Poll<()> {
        if let Poll::Ready(val) = Pin::new(&mut self.rx1).poll(cx) {
            println!("rx1 completed first with {:?}", val);
            return Poll::Ready(());
        }

        if let Poll::Ready(val) = Pin::new(&mut self.rx2).poll(cx) {
            println!("rx2 completed first with {:?}", val);
            return Poll::Ready(());
        }

        Poll::Pending
    }
}

#[tokio::main]
async fn main() {
    let (tx1, rx1) = oneshot::channel();
    let (tx2, rx2) = oneshot::channel();

    tokio::spawn(async move {
      tx2.send("two");
    });

    tokio::spawn(async move {
      tx1.send("one");
    });

    MySelect { rx1, rx2 }.await;
}
```

### 语法
select! 宏能够处理两个以上的分支，事实上当前的分支限制数是 64 个，每个分支的结构如下
```rust
<pattern> = <async experssion> => <handler>
```
它的语法类似与 Go 语言中的 `select` 关键字。它有以下特点:
- 在多个 <async expression> 中选择一个执行，而选择是随机的，<handler> 可以访问 <pattern> 得到的绑定数据。
- 支持返回值。
- 支持任意的异步表达式。

使用 `oneshot::Channel` 的输出结果及 TCP 连接的创建作为 `select!` 的表达式:
```rust
use tokio::{net::TcpStream, sync::oneshot};

#[tokio::main]
async fn main() {
    let (tx, rx) = oneshot::channel();

    tokio::spawn(async move {
        let _ = tx.send("done");
    });

    tokio::select! {
      socket = TcpStream::connect("localhost:3456") => {
        println!("Socket connected: {:?}", socket);
      }
      msg = rx => {
        println!("received message first {:?}", msg);
      }
    }
}
```
或者启动 TcpListener 接收连接的循环
```rust
use std::io;

use tokio::{net::TcpListener, sync::oneshot};

#[tokio::main]
async fn main() -> io::Result<()> {
    let (tx, rx) = oneshot::channel();

    tokio::spawn(async move {
        let _ = tx.send("done");
    });

    let mut listener = TcpListener::bind("localhost:3456").await?;

    tokio::select! {
      _ = async {
        loop {
            let (socket, _) = listener.accept().await?;
            tokio::spawn(async move {process(socket)});
        }
        Ok::<_, io::Error>(())
      } => {}
      msg = rx => {
        println!("received message first {:?}", msg);
      }
    }

    Ok(())
}
```

### 获取返回值
```rust
async fn computation1() -> String {
  String::from("channel1")
}

async fn computation2() -> String {
  String::from("channel2")
}

#[tokio::main]
async fn main() {
  let out = tokio::select! {
    res1 = computation1() => res1,
    res2 = computation2() => res2,
  };

  println!("Got = {}", out);
}
```
### 错误处理
在 <handler> 块中使用 `?` 语句能够让错误传播出 `select!` 表达式。
```rust
use std::io;
use tokio::net::TcpListener;
use tokio::sync::oneshot;

#[tokio::main]
async fn main() -> io::Result<()> {
    let (tx, rx) = oneshot::channel();

    let listener = TcpListener::bind("localhost:3465").await?;

    tokio::select! {
      res = async {
        loop {
          let (socket, _) = listener.accept().await?;
          tokio::spawn(async move { process(sokcet) });
        }

        Ok::<_, io::Error>(())
      } => {
        res?;
      }
      _ = rx => {
        println!("terminating accept loop");
      }
    }

    Ok(())
}
```

### else
`select!` 表达式包含了一个 else 分支，因为需要对 `select!` 表达式进行求值，但是在使用模式匹配时可能所有的模式都匹配不上，在这种情况下我们就需要使用 else 分支来帮助 `select!` 求值。
```rust
use tokio::sync::mpsc;

#[tokio::main]
async fn main() {
    let (tx1, mut rx1) = mpsc::channel(32);
    let (tx2, mut rx2) = mpsc::channel(32);

    tokio::spawn(async move {
        // Send values on `tx1` and `tx2`.
        let _ = tx1.send("tx1").await;
    });

    tokio::spawn(async move {
        // Send values on `tx1` and `tx2`.
        let _ = tx2.send("tx2").await;
    });

    tokio::select! {
        Some(v) = rx1.recv() => {
           println!("Got {:?} from rx1", v);
        }
        Some(v) = rx2.recv() => {
            println!("Got {:?} from rx2", v);
        }
        else => {
          println!("Bot channels closed");
        }
    }
}
```
> 在我们创建任务时，所创建任务的异步代码块必须持有他使用的数据，但 select! 并没有这个限制，每个分支的表达式可以对数据进行借用以及并发的进行操作，在 Rust 的借用规则中，多个异步表达式能够借用同一个不可变引用，或者一个一步表达式能够借用一个可变引用。

### Loops
`select!` 可以和 `loop` 配合使用:
```rust
use tokio::sync::mpsc;

#[tokio::main]
async fn main() {
    let (tx1, mut rx1) = mpsc::channel(128);
    let (tx2, mut rx2) = mpsc::channel(128);
    let (tx3, mut rx3) = mpsc::channel(128);

    tokio::spawn(async move {
        tx1.send("tx1").await;
    });

    tokio::spawn(async move {
        tx2.send("tx2").await;
    });
    
    tokio::spawn(async move {
        tx3.send("tx3").await;
    });

    loop {
        let msg = tokio::select! {
            Some(msg) = rx1.recv() => msg,
            Some(msg) = rx2.recv() => msg,
            Some(msg) = rx3.recv() => msg,
            else => { break; }
        };

        println!("Got {}", msg);
    }

    println!("All channels have been closed.");
}
```
`select!` 宏会随机的选择可读的分支，在上例中当多个 Channel 中都有可读的数据时，将随机选择一个 Channel 来读取。这个实现是为了处理循环中消费消息的能力落后于生产消息这个场景所带来的问题，这个场景意味着 Channel 总会被填满，如果 `select!` 没有随机的选取分支，将导致循环中的 rx1 永远是第一个检查是否有数据可读的分支，如果 rx1 一直都有新的消息要处理，那其他分支中的 Channel 将永远不会被消费。

> 如果 select! 被求值时，其中的多个 Channel 都存在排队中的消息，只有一个 Channel 的消息会被消费，其他所有的 Channel 都不会进行任何检查，他们的消息会被一直存在 Channel 中，直到循环的下一轮迭代，这些消息并不会丢失。

### pin!
```rust
use tokio::sync::mpsc;

async fn action() -> String {
    tokio::time::sleep(tokio::time::Duration::from_secs(1)).await;
    String::from("aa")
}

#[tokio::main]
async fn main() {
    let (tx, mut rx) = mpsc::channel(128);

    let operation = action();
    tokio::pin!(operation);

    tokio::spawn(async move {
        let _ = tx.send(2).await;
    });

    loop {
        tokio::select! {
            v = &mut operation => {
                println!("GOT {:?}", v);
                break;
            },
            Some(v) = rx.recv() => {
                println!("{:?}", v);
                if v % 2 == 0 {
                    // break;
                }
            }
        }
    }
}
```
在 `select!` 循环中，我们使用了 &mut operation 而不是直接使用 operation。这个 operation 变量在整个异步的操作中都存在，每次循环的迭代都会使用同一个 operation 而不是每次都调用一次 `action()`。

## Streams
Stream 表示一个异步的数据序列，我们用 Stream Trait 来表示跟标准库的 `std::iter::Iterator` 类似的概念。

Tokio 提供的 Stream 支持是通过一个独立的包来实现的，他就是 tokio-stream
```rust
tokio-stream = "0.1"
```

```rust
use tokio_stream::StreamExt;

#[tokio::main]
async fn main() {
    let stream = tokio_stream::iter(&[1, 2, 3, 4, 5]);

    let mut stream = stream.take(3);

    while let Some(v) = &stream.next().await {
        println!("GOT = {:?}", v)
    }
}
```
