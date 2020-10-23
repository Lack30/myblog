---
title: "Spring框架的核心总结"
date: 2019-08-19T16:56:42+08:00
lastmod: 2019-08-19T16:56:42+08:00
draft: false
keywords: []
description: ""
tags: ["java", "spring"]
categories: ["随笔"]
author: ""

# You can also close(false) or open(true) something for this content.
# P.S. comment can only be closed
comment: true
toc: true
autoCollapseToc: true
postMetaInFooter: false
hiddenFromHomePage: false
# You can also define another contentCopyright. e.g. contentCopyright: "This is another copyright."
contentCopyright: false
reward: false
mathjax: false
mathjaxEnableSingleDollar: false
mathjaxEnableAutoNumber: false

# You unlisted posts you might want not want the header or footer to show
hideHeaderAndFooter: false

# You can enable or disable out-of-date content warning for individual post.
# Comment this out to use the global config.
#enableOutdatedInfoWarning: false

flowchartDiagrams:
  enable: false
  options: ""

sequenceDiagrams: 
  enable: false
  options: ""

---

最近在学习Java语言，从而也学习了SpringFramework 这个大名鼎鼎的框架。从而做一些的记录。

> 题外话: 学习过几种不同的语言，后来知道所有的编程语言里所有的概念翻来覆去都是一样的事物，只是它们被不同的术语所描述，加上大部分中文翻译，又扯上一些专有名词，让一些本来简单的概念变得复杂而深奥。不知是因人的有限，还是那些书籍的作者有意为之，其实很多的东西本来都是很简单了，这些奇怪的名词反而让初学者糊涂起来。如果有刚开始学习编程的同学看到这里，也请注意了，不要被一些概念和名字带偏了，究其本质，也就那样。

# Spring 基本概念

其实编程语言和框架的发展都是为了**实际使用**而来的，既然是使用，怎么使用，怎么简单的使用，怎么用更舒服就成为了其发展的主要动力了。Java框架的发展也是如此，所以spring代替了Java EE，再到后来 Spring Boot 的热门，皆是如此。因此框架的作者就会想法设法简化一些不必要和繁琐的东西。而 Spring 的核心思想就是：`简化 Java 开发`。

为了达到这个目的，就有了以下的四个策略：

- 基于POJO的轻量级和最小入侵性编程
- 通过依赖注入和面向接口实现松耦合
- 基于切面的惯例进行声明式编程
- 通过切面和模板减少样板式代码

## POJO
这个名称就是符合上面提到的问题。POJO  (Plain Old Java Object) ...... 其实就是个`普通Java 类`，没有其他的东西了，只不过是作者为了应付那些反对叫嚣的人而扯出来的花里胡哨的名称。

因为作者的意图就是不让框架本身的API干扰到业务代码中一些定义的类，这样可以尽量是业务的代码更加干净，耦合度低，容易修改和测试，也就是所以的“最小入侵性”。但是绝对的干净还是做不到的，所以一般的业务代码上就常常出现了`注解`。

## 依赖注入和控制反转
又是看起来就 **高大上** 的词汇。依赖注入(dependency injection)和控制反转(inversion of control) 这两者其实`就是同一个东西`，只是它们的表述不同而已。因为一般的应用中，要完成一个实际的功能，基本不可能只有一个类，而是多个类同时使用，使用中就会互相影响。用一个例子来说明吧，我们做一个功能，需要A类和B类，现在需要用A类创建B，修改B，删除B，A是依赖B的，但是做的功能只是输入B的信息而已，这样太麻烦了，而且它们之间联系太多，如果B需要修改，那A也就要修改。所以在 spring 中，A如果需要B，它不是直接创建B，而是找 spring，这就是将 B 的控制给了 spring， 实现`控制反转`。对spring 来说，当A需要B时，它为A提供，这就是`依赖注入`，看！只是表述不同而已。

> spring 的出现，解耦和不同类之间的依赖，谁需要谁，都需要找 spring了。

## AOP
又是 spring  的核心概念。 AOP (aspect-oriented programming) 面向切面编程......，面向.....编程 这类又容易让人混乱，其实就是它们的关注点不同而已。程序员写代码的思想，或者习惯。
- 面向过程编程:  我就看实现一个功能需要什么步骤，然后用代码表示出这些步骤就好了，我不管代码的重用，耦合性问题。关注点是 步骤、过程。
- 面向对象编程: 我需要实现该功能，但是我需要考虑到流程的结构，代码重用，耦合问题。我需要先建立一个对象，对这个对象实例化实现功能。关注点是 对象。
- 面向切面编程: 这个是在 spring 里第一次见到的，它关注于应用中的 核心业务 模块，而设法将一些次要的，辅助的功能统一管理，如日志、安全、验证等。

# spring Bean
而在 spring 中实现了 ioc 的就是这个 `bean`。它是spring中的容器，用来管理构成应用的组件和业务代码类。它是spring的核心。

## Bean的创建
创建 Bean 有三种不同的方式：
- 使用 xml 配置文件创建
- 使用 java 注解创建
- 使用 java Config 创建

## Bean 的生命周期

![](https://img2018.cnblogs.com/blog/1219190/201908/1219190-20190819211607950-708913569.png)

具体过程为：
1.Spring 对 bean 进行实例化
2.Spring 将值和 bean 的引用注入到 bean 对应的属性中
3.如果 bean 实现了 `BeanNameAware` 接口， Spring 将 bean 的 ID 传递给 `setBeanName()` 方法
4.如果 bean 实现了`BeanFactoryAware`接口， Spring 将调用 `setBeanFactory()` 方法，将 BeanFactory 容器实例传入
5.如果 bean 实现了`ApplicationContextAware`接口， Spring 将调用 `setApplicationContext()` 方法，将 bean 所在的应用上下文引用传进来
6.如果 bean 实现了`BeanPostProcesser`接口， Spring 将调用它们的 `postProcessBeforeInitialization()` 方法
7.如果 bean 实现了`InitializationBean` 接口，Spring 将调用它们的 `afterPropertiesSet()` 方法。类似地，如果 bean 使用 init-method 声明了初始化方法，该方法也会被调用
8.如果 bean 实现了`BeanPostProcessor`接口，Spring 将调用它们的 `postProcessAfterInitialization()` 方法
9.此时，bean 已经准备就绪，可以被应用程序使用了，它们将一直驻留在应用上下文中，直到该应用上下文被销毁
10.如果 bean 实现了  `DisposableBean` 接口，Spring 将调用它们的 `destroy()` 接口方法。同样，如果 bean 使用 destroy-method 声明了销毁方法，该方法也会被调用
