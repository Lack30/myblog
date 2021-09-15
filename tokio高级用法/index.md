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
