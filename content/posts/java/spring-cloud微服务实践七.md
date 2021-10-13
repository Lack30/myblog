---
title: "Spring Cloud微服务实践七"
date: 2019-08-18T16:54:25+08:00
lastmod: 2019-08-18T16:54:25+08:00
draft: false
keywords: []
description: ""
tags: ["java", "spring"]
categories: ["微服务"]
author: "Lack"
---

在spring cloud 2.x以后,由于zuul一直停滞在1.x版本,所以spring官方就自己开发了一个项目 `Spring Cloud Gateway`.作为spring cloud微服务的网关组件.
> 注:这一个系列的开发环境版本为 java1.8, spring boot2.x, spring cloud Greenwich.SR2, IDE为 Intelli IDEA

# spring cloud gateway 入门
根据官方的简介,它是spring mvc基础之上,旨在提供一个简单有效的路由管理方式,如 安全，监控/指标，和限流等.

## 相关概念
- Route（路由）：这是网关的基本构建部分。它由一个 ID，一个目标 URI，一组断言和一组过滤器定义。如果断言为真，则路由匹配。
- Predicate（断言）：这是一个 Java 8 的 Predicate。输入类型是一个 ServerWebExchange。我们可以使用它来匹配来自 HTTP 请求的任何内容，例如 headers 或参数。
- Filter（过滤器）：这是`org.springframework.cloud.gateway.filter.GatewayFilter`的实例，我们可以使用它修改请求和响应。

## 工作流程
![](https://img2018.cnblogs.com/blog/1219190/201908/1219190-20190817205240036-1153075693.png)

客户端向 Spring Cloud Gateway 发出请求。如果 Gateway Handler Mapping 中找到与请求相匹配的路由，将其发送到 Gateway Web Handler。Handler 再通过指定的过滤器链来将请求发送到我们实际的服务执行业务逻辑，然后返回。 过滤器之间用虚线分开是因为过滤器可能会在发送代理请求之前（“pre”）或之后（“post”）执行业务逻辑。

Spring Cloud Gateway 的特征：
- 基于 Spring Framework 5，Project Reactor 和 Spring Boot 2.0
- 动态路由
- Predicates 和 Filters 作用于特定路由
- 集成 Hystrix 断路器
- 集成 Spring Cloud DiscoveryClient
- 易于编写的 Predicates 和 Filters
- 限流
- 路径重写

> 注: 以上引自: http://www.ityouknow.com

## 简单使用
### 添加依赖
```
    <properties>
        <java.version>1.8</java.version>
        <spring-cloud.version>Greenwich.SR2</spring-cloud.version>
    </properties>

    <dependencies>
        <dependency>
            <groupId>org.springframework.cloud</groupId>
            <artifactId>spring-cloud-starter-gateway</artifactId>
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

### 配置文件
spring cloud gateway底层使用netty+webflux, 不再依赖web了
```
server:
  port: 8080
spring:
  cloud:
    gateway:
      routes:
      - id: iyk_route
        uri: http://www.ityouknow.com
        predicates:
        - Path=/spring-cloud
```
说明下该配置:
- id：自定义的路由 ID，保持唯一
- uri：目标服务地址
- predicates：路由条件，Predicate 接受一个输入参数，返回一个布尔值结果。该接口包含多种默认方法来将 Predicate 组合成其他复杂的逻辑（比如：与，或，非）。
- filters：过滤规则

同样的,转发功能也可以使用代码来实现:
```java
// 直接写在启动类中
    @Bean
    public RouteLocator customRouteLocator(RouteLocatorBuilder builder) {
        return builder.routes()
                .route("path_route", r -> r.path("/about")
                        .uri("http://ityouknow.com"))
                .build();
    }
```
> 注: 虽然两种方法都可以,但还是建议写在配置文件中

## 路由规则
Spring Cloud Gateway 是通过 Spring WebFlux 的 HandlerMapping 做为底层支持来匹配到转发路由，Spring Cloud Gateway 内置了很多 Predicates 工厂，这些 Predicates 工厂通过不同的 HTTP 请求参数来匹配，多个 Predicates 工厂可以组合使用。

### predicates
Predicate 来源于 Java 8，是 Java 8 中引入的一个函数，Predicate 接受一个输入参数，返回一个布尔值结果。该接口包含多种默认方法来将 Predicate 组合成其他复杂的逻辑（比如：与，或，非）。可以用于接口请求参数校验、判断新老数据是否有变化需要进行更新操作。

在 Spring Cloud Gateway 中 Spring 利用 Predicate 的特性实现了各种路由匹配规则，有通过 Header、请求参数等不同的条件来进行作为条件匹配到对应的路由。网上有一张图总结了 Spring Cloud 内置的几种 Predicate 的实现。

![](https://img2018.cnblogs.com/blog/1219190/201908/1219190-20190817213554743-1470040946.png)

接下来我们就来看看这些规则的具体使用方法:
### 时间匹配
predicate 支持设置一个时间,以这个时间为分界线,这个时间前的不能访问,这个时间之后的可以访问.
```
spring:
  cloud:
    gateway:
      routes:
       - id: time_route
        uri: http://example.com
        predicates:
         - After=2019-08-17T12:00:00+08:00[Asia/Shanghai]
```
Spring 是通过 ZonedDateTime 来对时间进行的对比，ZonedDateTime 是 Java 8 中日期时间功能里，用于表示带时区的日期与时间信息的类，ZonedDateTime 支持通过时区来设置时间，中国的时区是：`Asia/Shanghai`。

After Route Predicate 是指在这个时间之后的请求都转发到目标地址。上面的示例是指，请求时间在 2018年1月20日6点6分6秒之后的所有请求都转发到地址http://example.com。+08:00是指时间和UTC时间相差八个小时，时间地区为`Asia/Shanghai`。

添加完路由规则之后，访问地址http://localhost:8080会自动转发到http://example.com。

Before Route Predicate 刚好相反，在某个时间之前的请求的请求都进行转发。我们把上面路由规则中的 After 改为 Before，如下：
```
spring:
  cloud:
    gateway:
      routes:
       - id: before_route
        uri: http://example.com
        predicates:
         - Before=2019-08-17T12:00:00+08:00[Asia/Shanghai]
```
既然有这个时间前`After`和这个时间后`Before`,predicate还支持在一段时间之内匹配,那就需要使用`Between`
```
spring:
  cloud:
    gateway:
      routes:
       - id: after_route
        uri: http://example.com
        predicates:
         - Between=2019-08-17T08:00:00+08:00[Asia/Shanghai], 2019-08-17T09:00:00+08:00[Asia/Shanghai]
```
这个功能刚好可以使用在一些抢购活动中.
### Cookie 匹配
Cookie Route Predicate 可以接收两个参数，一个是 Cookie name ,一个是正则表达式，路由规则会通过获取对应的 Cookie name 值和正则表达式去匹配，如果匹配上就会执行路由，如果没有匹配上则不执行。
```
spring:
  cloud:
    gateway:
      routes:
       - id: cookie_route
         uri: http://example.com
         predicates:
         - Cookie=a,b.c
```
这表示请求的cookie需要携带 a=b.c 才可以访问,否则就报404错误,可以使用 `curl http://localhost:8080 --cookie "a=b.c"`

### Header 匹配
Header Route Predicate 和 Cookie Route Predicate 一样，也是接收 2 个参数，一个 header 中的属性名称和一个正则表达式，这个属性值和正则表达式匹配则执行。
```
spring:
  cloud:
    gateway:
      routes:
      - id: header_route
        uri: http://example.com
        predicates:
        - Header=X-Request-Id, \d+
```
同样的可以使用命令`url http://localhost:8080 --header "X-Request-Id:11"`来测试.

### Host 匹配
Host Route Predicate 接收一组参数，一组匹配的域名列表，这个模板是一个 ant 分隔的模板，用.号作为分隔符。它通过参数中的主机地址作为匹配规则
```
spring:
  cloud:
    gateway:
      routes:
      - id: header_route
        uri: http://example.com
        predicates:
        - Host=**.example.com
```
### 请求方法匹配
可以通过请求方式GET，POST，PATH和DELETE方法进行匹配：
```
spring:
  cloud:
    gateway:
      routes:
      - id: method_route
        uri: https://example.org
        predicates:
        - Method=GET
```
### 请求路径匹配
 predicate接受两个参数，一个`PathMatcher` 表达式 和一个可选参数 `matchOptionalTrailingSeparator`
```
spring:
  cloud:
    gateway:
      routes:
      - id: host_route
        uri: https://example.org
        predicates:
        - Path=/foo/{segment},/bar/{segment}
```
能匹配到`/foo/1`, `/foo/bar` 或` /bar/baz`等路径。
同时也可以使用代码获取：
```java
Map<String, String> uriVariables = ServerWebExchangeUtils.getPathPredicateVariables(exchange);
String segment = uriVariables.get("segment");
```

### 请求参数匹配
Query Route Predicate 支持传入两个参数，一个是属性名一个为属性值，属性值可以是正则表达式。
```
spring:
  cloud:
    gateway:
      routes:
      - id: query_route
        uri: https://example.org
        predicates:
        - Query=baz
```

### ip地址匹配
RemoteAddr Route Predicate 支持匹配相应的ip地址，如(IPv4 or IPv6)，或者一个网段`192.168.0.1/16`，一个地址`192.168.0.1`
```
spring:
  cloud:
    gateway:
      routes:
      - id: remoteaddr_route
        uri: https://example.org
        predicates:
        - RemoteAddr=192.168.1.1/24
```

### 权重匹配
Weight Route Predicate 接受两个参数，分组和权重：
```
spring:
  cloud:
    gateway:
      routes:
      - id: weight_high
        uri: https://weighthigh.org
        predicates:
        - Weight=group1, 8
      - id: weight_low
        uri: https://weightlow.org
        predicates:
        - Weight=group1, 2
```
### 组合使用
除此之外，这些匹配还可以组合起来使用
```
spring:
  cloud:
    gateway:
      routes:
       - id: host_foo_path_headers_to_httpbin
        uri: http://example.com
        predicates:
        - Host=**.foo.org
        - Path=/headers
        - Method=GET
        - Header=X-Request-Id, \d+
        - Query=foo, ba.
        - Query=baz
        - Cookie=chocolate, ch.p
        - After=2019-08-18T12:00:00+08:00[Asia/Shanghai]
```
各种 Predicates 同时存在于同一个路由时，请求必须同时满足所有的条件才被这个路由匹配。
> 一个请求满足多个路由的谓词条件时，请求只会被首个成功匹配的路由转发

# 服务化
前面已经介绍了spring cloud gateway 的简单使用，现在我们就把它融入到微服务中，

## 添加依赖
```
<dependency>
    <groupId>org.springframework.cloud</groupId>
    <artifactId>spring-cloud-starter-netflix-eureka-client</artifactId>
</dependency>
```

## 配置文件
修改配置文件，添加discovery的配置
```
server:
  port: 8888
spring:
  application:
    name: gateway
  cloud:
    gateway:
     discovery:
        locator:
         enabled: true
eureka:
  client:
    service-url:
      defaultZone: http://localhost:8000/eureka/
logging:
  level:
    org.springframework.cloud.gateway: debug
```
配置说明：

- spring.cloud.gateway.discovery.locator.enabled：是否与服务注册于发现组件进行结合，通过 serviceId 转发到具体的服务实例。默认为 false，设为 true 便开启通过服务中心的自动根据 serviceId 创建路由的功能。
- eureka.client.service-url.defaultZone指定注册中心的地址，以便使用服务发现功能
- logging.level.org.springframework.cloud.gateway 调整相 gateway 包的 log 级别，以便排查问题

## 启动类
```java
@SpringBootApplication
@EnableDiscoveryClient
public class GatewayApplication {
    public static void main(String[] args) {
        SpringApplication.run(GatewayApplication.class, args);
    }
}
```

修改完成后启动项目，访问注册中心地址 http://localhost:8000/ 即可看到名为GATEWAY的服务。

## 测试
将 spring cloud gateway 注册到服务中心之后，网关会自动代理所有的在注册中心的服务，访问这些服务的语法为：`http://网关地址:端口/服务中心注册serviceId/具体的url`。
假如 `producer` 有一个 `hello` 服务，那使用 `gateway` 访问就变成 `http://localhost:8888/producer/hello`。

# 基于Filter实现的功能
Spring Cloud Gateway 的 Filter 的生命周期有两个：“pre” 和 “post”。

- PRE： 这种过滤器在请求被路由之前调用。我们可利用这种过滤器实现身份验证、在集群中选择请求的微服务、记录调试信息等。
- POST：这种过滤器在路由到微服务以后执行。这种过滤器可用来为响应添加标准的 HTTP Header、收集统计信息和指标、将响应从微服务发送给客户端等。

Spring Cloud Gateway 的 Filter 分为两种：GatewayFilter 与 GlobalFilter。GlobalFilter 会应用到所有的路由上，而 GatewayFilter 将应用到单个路由或者一个分组的路由上。

Spring Cloud Gateway 内置了9种 GlobalFilter，比如 Netty Routing Filter、LoadBalancerClient Filter、Websocket Routing Filter 等，具体大家参考官网内容。
利用 GatewayFilter 可以修改请求的 Http 的请求或者响应，或者根据请求或者响应做一些特殊的限制。 

## 修改请求参数
我们可以使用 `AddRequestParameter GatewayFilter`来在转发时添加请求的参数。

*application.xml*
```
spring:
  cloud:
    gateway:
      routes:
      - id: add_request_parameter_route
        uri: http://example.org
        filters:
        - AddRequestParameter=foo, bar
```
这样以来就会给每个请求都加上foo=bar

## 路由转发
我们在配置中，指定转发的对象都是直接使用uri的，但是我们知道微服务中服务提供者通常都是动态变化的，所以为了应对这样的情况，可以修改uri为指定应用的名称。
```
#格式为：lb://应用注册服务名
uri: lb://producer
```
这里其实默认使用了全局过滤器 LoadBalancerClient ，当路由配置中 uri 所用的协议为 lb 时（以uri: lb://producer为例），gateway 将使用 LoadBalancerClient 把 spring-cloud-producer 通过 eureka 解析为实际的主机和端口，并进行负载均衡。

## 修改请求路径
StripPrefix Filter 是一个请求路径截取的功能，我们可以利用这个功能来做特殊业务的转发
*application.xml*
```
spring:
  cloud:
    gateway:
      routes:
      - id: nameRoot
        uri: http://nameservice
        predicates:
        - Path=/name/**
        filters:
        - StripPrefix=2
```
上面这个配置的例子表示，当请求路径匹配到`/name/**`会将包含name和后边的字符串接去掉转发， StripPrefix=2就代表截取路径的个数，这样配置后当请求`/name/bar/foo`后端匹配到的请求路径就会变成`http://nameservice/foo`。

> PrefixPath Filter 的作用和 StripPrefix 正相反，是在 URL 路径前面添加一部分的前缀。

## 路由限流
为了应对服务中限速的需求，spring cloud gateway 提供了结合 redis 数据库的限流方案，它需要添加对应的依赖包`spring-boot-starter-data-redis-reactive`
*pom.xml*
```
<dependency>
  <groupId>org.springframework.cloud</groupId>
  <artifactId>spring-boot-starter-data-redis-reactive</artifactId>
</dependency>
```
*application.yml*
```
spring:
  application:
    name: gateway
  redis:
    host: localhost
    password:
    port: 6379
  cloud:
    gateway:
     discovery:
        locator:
         enabled: true
     routes:
     - id: requestratelimiter_route
       uri: http://example.org
       filters:
       - name: RequestRateLimiter
         args:
           redis-rate-limiter.replenishRate: 10
           redis-rate-limiter.burstCapacity: 20
           key-resolver: "#{@userKeyResolver}"
       predicates:
         - Method=GET
```

- filter 名称必须是 RequestRateLimiter
- redis-rate-limiter.replenishRate：允许用户每秒处理多少个请求
- redis-rate-limiter.burstCapacity：令牌桶的容量，允许在一秒钟内完成的最大请求数
- key-resolver：使用 SpEL 按名称引用 bean

添加配置类*Config.java*
```java
@Component
public class Config {

    // 根据请求参数中的 user 字段来限流
    @Primary
    @Bean
    public KeyResolver userKeyResolver() {
        return exchange -> Mono.just(exchange.getRequest().getQueryParams().getFirst("user"));
    }

    // 设置根据请求 IP 地址来限流
    @Bean
    public KeyResolver ipKeyResolver() {
        return exchange -> Mono.just(exchange.getRequest().getRemoteAddress().getHostName());
    }
}
```

## 熔断器
同样的，使用Filter的特性，我们也可以实现熔断器的功能。首先添加依赖包：
*pom.xml*
```
<dependency>
  <groupId>org.springframework.cloud</groupId>
  <artifactId>spring-cloud-starter-netflix-hystrix</artifactId>
</dependency>
```

然后添加熔断器的配置 *application.yml*
```
spring:
  cloud:
    gateway:
      routes:
      - id: hystrix_route
        uri: lb://producer
        predicates:
        - Path=/consumingserviceendpoint
        filters:
        - Hystrix=myCommandName
        - name: Hystrix
          args:
            name: fallbackcmd
            fallbackUri: forward:/incaseoffailureusethis
```
配置后gateway 将使用 myCommandName 作为名称生成 HystrixCommand 对象来进行熔断管理，`fallbackUri: forward:/incaseoffailureusethis`配置了 fallback 时要会调的路径，当调用 Hystrix 的 fallback 被调用时，请求将转发到`/incaseoffailureuset`这个 URI。

## 路由重试
RetryGatewayFilter 是 Spring Cloud Gateway 对请求重试提供的一个 GatewayFilter Factory
添加配置 *application.yml*
```
spring:
  cloud:
    gateway:
      routes:
      - id: retry_test
        uri: http://localhost:8080/flakey
        predicates:
        - Host=*.retry.com
        filters:
        - name: Retry
          args:
            retries: 3
            statuses: BAD_GATEWAY
            backoff:
              firstBackoff: 10ms
              maxBackoff: 50ms
              factor: 2
              basedOnPreviousValue: false
```
- retries：应尝试的重试次数
- statuses：应该重试的HTTP状态代码，取值参考org.springframework.http.HttpStatus
- methods：应该重试的HTTP方法，取值参考org.springframework.http.HttpMethod
- series：要重试的一系列状态代码，取值参考org.springframework.http.HttpStatus.Series
- exceptions：应该重试的异常列表
- backoff：重试时间间隔。 在firstBackoff x（因子n）的间隔之后执行重试，其中n是重试的次数。 如果配置了maxBackoff，则应用的最大间隔将限制为maxBackoff。 如果basedOnPreviousValue为true，则使用prevBackoff x factor计算间隔。
