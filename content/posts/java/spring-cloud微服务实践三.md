---
title: "Spring Cloud微服务实践三"
date: 2019-08-11T16:50:13+08:00
lastmod: 2019-08-11T16:50:13+08:00
draft: false
keywords: []
description: ""
tags: ["java", "spring"]
categories: ["微服务"]
author: "Lack"

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

上篇文章里我们实现了spring cloud中的服务提供者和使用者.接下来我们就来看看spring cloud中微服务的其他组件.
> 注:这一个系列的开发环境版本为 java1.8, spring boot2.x, spring cloud Greenwich.SR2, IDE为 Intelli IDEA
# 熔断器
spring cloud架构成员中有一个叫"熔断器".微服务中一个服务通常存在多级调用情况,在这种情况下就出现了一些严重的问题.假如其中的一个服务故障了,那么调用这个服务的使用者就会处于等待状态中,由于多级联调用,所以后续的调用者也会处于这种情况.因此错误就会在一个系统中被放大,从而出现了服务的"雪崩效应".为了应对这种效应,就有了"熔断器".
所谓熔断器,就是当服务提供者出现问题时,调用者发现了这个问题,它会快速响应报错.
> 如果它在一段时间内侦测到许多类似的错误，会强迫其以后的多个调用快速失败，不再访问远程服务器，从而防止应用程序不断地尝试执行可能会失败的操作，使得应用程序继续执行而不用等待修正错误，或者浪费CPU时间去等到长时间的超时产生。熔断器也可以使应用程序能够诊断错误是否已经修正，如果已经修正，应用程序会再次尝试调用操作.

## Hystrix特性
### 1.断路器机制
断路器很好理解, 当Hystrix Command请求后端服务失败数量超过一定比例(默认50%), 断路器会切换到开路状态(Open). 这时所有请求会直接失败而不会发送到后端服务. 断路器保持在开路状态一段时间后(默认5秒), 自动切换到半开路状态(HALF-OPEN). 这时会判断下一次请求的返回情况, 如果请求成功, 断路器切回闭路状态(CLOSED), 否则重新切换到开路状态(OPEN). Hystrix的断路器就像我们家庭电路中的保险丝, 一旦后端服务不可用, 断路器会直接切断请求链, 避免发送大量无效请求影响系统吞吐量, 并且断路器有自我检测并恢复的能力.
### 2.Fallback
Fallback相当于是降级操作. 对于查询操作, 我们可以实现一个fallback方法, 当请求后端服务出现异常的时候, 可以使用fallback方法返回的值. fallback方法的返回值一般是设置的默认值或者来自缓存
### 3.资源隔离
在Hystrix中, 主要通过线程池来实现资源隔离. 通常在使用的时候我们会根据调用的远程服务划分出多个线程池. 例如调用产品服务的Command放入A线程池, 调用账户服务的Command放入B线程池. 这样做的主要优点是运行环境被隔离开了. 这样就算调用服务的代码存在bug或者由于其他原因导致自己所在线程池被耗尽时, 不会对系统的其他服务造成影响. 但是带来的代价就是维护多个线程池会对系统带来额外的性能开销. 如果是对性能有严格要求而且确信自己调用服务的客户端代码不会出问题的话, 可以使用Hystrix的信号模式(Semaphores)来隔离资源.
> 这段来自: http://www.ityouknow.com

# Feign Hystrix
spring cloud中熔断器组件是结合`Feign`库一起使用的.所以它的代码是在上一篇中的`consumer`基础上添加的.

## 创建工程项目
创建一个spring cloud工程项目,命名为`hystrix`.

## 依赖文件 pom
修改依赖文件 pom.xml
```
<properties>
        <java.version>1.8</java.version>
        <spring-cloud.version>Greenwich.SR2</spring-cloud.version>
    </properties>

    <dependencies>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter</artifactId>
        </dependency>

        <dependency>
            <groupId>org.springframework.cloud</groupId>
            <artifactId>spring-cloud-starter-openfeign</artifactId>
        </dependency>

        <dependency>
            <groupId>org.springframework.cloud</groupId>
            <artifactId>spring-cloud-starter-netflix-hystrix</artifactId>
        </dependency>

        <dependency>
            <groupId>org.springframework.cloud</groupId>
            <artifactId>spring-cloud-starter-netflix-eureka-server</artifactId>
        </dependency>

        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-test</artifactId>
            <scope>test</scope>
        </dependency>
    </dependencies>

    <dependencyManagement>
        <dependencies>
            <dependency>
                <groupId>org.springframework.cloud</groupId>
                <artifactId>spring-cloud-dependencies</artifactId>
                <version>${spring-cloud.version}</version>
                <type>pom</type>
                <scope>import</scope>
            </dependency>
        </dependencies>
    </dependencyManagement>
```

## 配置文件
修改配置文件 application.properties
```
spring.application.name=hystrix

server.port=9002
# 其他和consumer相同,主要是hystrix的配置
feign.hystrix.enabled=true

eureka.client.service-url.defaultZone=http://localhost:8000/eureka/
```

## 远程调用
```java
// com/xingyys/hystrix/remote/HelloRemote.java
// 指定fallback属性
@FeignClient(name = "producer", fallback = HelloRemoteHystrix.class)
public interface HelloRemote {
    @RequestMapping(value = "/hello")
    public String hello(@RequestParam(value = "name") String name);
}
```

## hystrix熔断器
```java
// com/xingyys/hystrix/remote/HelloRemoteHystrix
@Component
public class HelloRemoteHystrix implements HelloRemote {
    @Override
    public String hello(@RequestParam String name) {
        return "hello " + name + " failed!";
    }
}
```

## 控制器
```java
// com/xingyys/hystrix/controller/HystrixController.java
@RestController
public class HystrixController {

    // @Autowired 也可以, 因为idea的问题, 会显示红色
    @Resource
    HelloRemote helloRemote;

    @RequestMapping("/hello/{name}")
    public String hello(@PathVariable("name") String name) {
        return helloRemote.hello(name);
    }
}
```

## 启动类
```
@SpringBootApplication
@EnableDiscoveryClient
@EnableFeignClients(basePackages = "com.xingyys.hystrix.remote")
public class HystrixApplication {

    public static void main(String[] args) {
        SpringApplication.run(HystrixApplication.class, args);
    }

}
```

## 编译,打包,启动
```bash
cd hystrix
mvn clean package -Dmaven.test.skip=true
java -jar target/hystrix-0.0.1-SNAPSHOT.jar
```

# 测试
依次启动discovery,producer,consumer和hystrix
访问`http://127.0.0.1:8000`,应用列表中新增了`HYSTRIX`.
访问`http://127.0.0.1:9002/hello/xingyys`,返回`hello xingyys!`,`consumer`的功能依然可用.
然后断开producer,返回`http://127.0.0.1:9001/hello/xingyys`,原来的`consumer`已经500错误.
而访问`http://127.0.0.1:9002/hello/xingyys`返回为:`hello xingyys failed!`,熔断器功能可用!
