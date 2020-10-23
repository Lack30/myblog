---
title: python装饰器
date: 2018-03-31 19:55:04
update: 2018-05-31 09:57:17
tags: 
 - python
categories: 
 - 随笔
---
![](http://image.xingyys.club/blog/python.jpg)
# 简单的装饰器函数：
```python
import time
from functools import wraps

def timethis(func):
	"""
	Decorator that reports the execution time.
	"""
    @wraps(func)
    def wrapper(*args, **kwargs):
        start = time.time()
        result = func(*args, **kwargs)
        end = time.time()
        print(func.__name__, end-start)
        return result
    return wrapper
```
函数的功能很简单，就是输出调用函数的执行时间。

```python
In [2]: @timethis
   ...: def countdown(n):
   ...:     while n > 0:
   ...:         n -= 1
   ...:         

In [3]: countdown(100000)
countdown 0.009751319885253906
```

本质上来说python的装饰器就是一个函数外再包装一个函数，等同于：
```python
timethis(countdown(100000))
```
装饰器内部的wrapper()函数中使用*args和**kwargs来接受任意参数，并用新的函数包装器来代替原来函数，其中的func就是原来的函数，即调用包装器的函数。而使用@wraps(func)的目的时保留原始函数的元数据。

```python
In [19]: @timethis
    ...: def countdown(n:int):
    ...:     '''counts down'''
    ...:     while n > 0:
    ...:         n -= 1
    ...:         

In [20]: countdown(100000)
countdown 0.008384943008422852

In [21]: countdown.__name__
Out[21]: 'countdown'

In [22]: countdown.__doc__
Out[22]: 'counts down'

In [23]: countdown.__annotations__
Out[23]: {'n': int}
```
输出的原始函数的元数据都正常
再来看看去掉wraps()函数的

```python
In [26]: countdown.__name__
Out[26]: 'wrapper'

In [27]: countdown.__doc__

In [28]: countdown.__annotations__
Out[28]: {}
```

@wraps 有一个重要特征是它能让你通过属性 wrapped 直接访问被包装函数。例如:
```python
In [34]: countdown.__wrapped__.__name__
Out[34]: 'countdown'
```
`__wrapped__` 属性还能让被装饰函数正确暴露底层的参数签名信息。例如：
```python
In [43]: from inspect import signature
In [44]: signature(countdown)
Out[44]: <Signature (n:int)>
```

# 带参数的装饰器
```python 
import logging
from functools import wraps

def logged(level, name=None, message=None):

    def decorate(func):
        logname = name if name else func.__module__
        log = logging.getLogger(logname)
        logmsg = message if message else func.__name__

        @wraps(func)
        def wrapper(*args, **kwargs):
            log.log(level, logmsg)
            return func(*args, **kwargs)
        return wrapper
    
    return decorate

@logged(logging.DEBUG)
def add(x, y):
    return x + y

@logged(logging.CRITICAL, 'example')
def spam():
    print("Spam!")
```

# 带可选参数的装饰器
```python
import logging
from functools import wraps, partial

def logged(func=None, *, level=logging.DEBUG, name=None, message=None):
    if func is None:
        return partial(logged, level=level, name=name, message=message)

    logname = name if name else func.__module__
    log = logging.getLogger(logname)
    logmsg = message if message else func.__name__

    @wraps(func)
    def wrapper(*args, **kwargs):
        log.log(level, logmsg)
        return func(*args, **kwargs)
    return wrapper
    

@logged
def add(x, y):
    return x + y

@logged(level=logging.CRITICAL, name='example')
def spam():
    print("Spam!")

```


  [1]: ./attachments/python-type.md "python-type"