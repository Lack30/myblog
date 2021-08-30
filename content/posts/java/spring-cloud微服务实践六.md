---
title: "Spring Cloud微服务实践六"
date: 2019-08-16T16:53:47+08:00
lastmod: 2019-08-16T16:53:47+08:00
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

本篇我们就来认识下spring cloud中的zuul组件.

> 注:这一个系列的开发环境版本为 java1.8, spring boot2.x, spring cloud Greenwich.SR2, IDE为 Intelli IDEA

# zuul简介
## 关于zuul
其实在前面的内容中,我们已经搭建了一个微服务平台,也实现了该有的功能.但是一般的微服务架构中还会有api gateway.那么api gateway(网关)又是做什么用的呢?

1、简化客户端调用复杂度

在微服务架构模式下后端服务的实例数一般是动态的，对于客户端而言很难发现动态改变的服务实例的访问地址信息。因此在基于微服务的项目中为了简化前端的调用逻辑，通常会引入API Gateway作为轻量级网关，同时API Gateway中也会实现相关的认证逻辑从而简化内部服务之间相互调用的复杂度。

![](https://img2018.cnblogs.com/blog/1219190/201908/1219190-20190816082638080-1820804337.png)


2、数据裁剪以及聚合

通常而言不同的客户端对于显示时对于数据的需求是不一致的，比如手机端或者Web端又或者在低延迟的网络环境或者高延迟的网络环境。
因此为了优化客户端的使用体验，API Gateway可以对通用性的响应数据进行裁剪以适应不同客户端的使用需求。同时还可以将多个API调用逻辑进行聚合，从而减少客户端的请求数，优化客户端用户体验

![](https://img2018.cnblogs.com/blog/1219190/201908/1219190-20190816082655252-520422522.png)

3、多渠道支持

当然我们还可以针对不同的渠道和客户端提供不同的API Gateway,对于该模式的使用由另外一个大家熟知的方式叫Backend for front-end, 在Backend for front-end模式当中，我们可以针对不同的客户端分别创建其BFF，进一步了解BFF可以参考这篇文章：Pattern: Backends For Frontends



4、遗留系统的微服务化改造

对于系统而言进行微服务改造通常是由于原有的系统存在或多或少的问题，比如技术债务，代码质量，可维护性，可扩展性等等。API Gateway的模式同样适用于这一类遗留系统的改造，通过微服务化的改造逐步实现对原有系统中的问题的修复，从而提升对于原有业务响应力的提升。通过引入抽象层，逐步使用新的实现替换旧的实现。

![](https://img2018.cnblogs.com/blog/1219190/201908/1219190-20190816082706091-1135576661.png)

在Spring Cloud体系中， Spring Cloud Zuul就是提供负载均衡、反向代理、权限认证的一个API gateway。

> 注: 以上引用于 http://www.ityouknow.com/springcloud/2017/06/01/gateway-service-zuul.html

Spring Cloud Zuul路由是微服务架构的不可或缺的一部分，提供动态路由，监控，弹性，安全等的边缘服务。Zuul是Netflix出品的一个基于JVM路由和服务端的负载均衡器。

# spring cloud zuul 初使用
在了解了gateway的作用和zuul之后,我们就来实现它:

## 添加依赖
```
<properties>
        <java.version>1.8</java.version>
        <spring-cloud.version>Greenwich.SR2</spring-cloud.version>
    </properties>

    <dependencies>
        <dependency>
            <groupId>org.springframework.cloud</groupId>
            <artifactId>spring-cloud-starter-netflix-zuul</artifactId>
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
```
spring.application.name=zuul
server.port=8888

#这里的配置表示，访问/producer/** 直接重定向到http://localhost:9000/**
zuul.routes.producer.path=/producer/**
zuul.routes.producer.url=http://localhost:9000/
```

## 启动类
```
@SpringBootApplication
@EnableZuulProxy
public class ZuulApplication {
    public static void main(String[] args) {
        SpringApplication.run(ZuulApplication.class, args);
    }

}
```
## 测试 
编译,启动`producer`和`zuul`访问`http://localhost:8888/producer/hello?name=xingyys`, 返回`Hello xingyys !`

# 服务化
上面的配置有很大的局限性,因为每一个服务都需要单独的添加配置信息,如果服务是动态的,就更不方便了.其实服务和url的映射关系在discovery里已经存在了,所以只需要将Zuul注册到eureka server上去发现其他服务，就可以实现对serviceId的映射.下面我们就来实现它!

## 添加依赖
```
        <dependency>
            <groupId>org.springframework.cloud</groupId>
            <artifactId>spring-cloud-starter-netflix-eureka-server</artifactId>
        </dependency>
```

## 配置文件
修改配置文件,添加discovery的配置
```
spring.application.name=zuul
server.port=8888

eureka.client.service-url.defaultZone=http://localhost:8000/eureka/

#这里的配置表示，访问/producer/** 直接重定向到http://localhost:9000/**
# zuul.routes.producer.path=/producer/**
# zuul.routes.producer.url=http://localhost:9000/
```
因为服务和url的映射信息已经存在,所有原来的配置可以删除.

## 启动类
开启服务注册
```
@SpringBootApplication
@EnableZuulProxy
@EnableDiscoveryClient
public class ZuulApplication {
    public static void main(String[] args) {
        SpringApplication.run(ZuulApplication.class, args);
    }

}
```
## 测试
重新编译,启动discovery, producer和zuul,访问`http://localhost:8888/producer/hello?name=xingyys`, 返回`Hello xingyys !`

# zuul 高级应用
zuul除了之前使用的网关和路由转发之外,还有更多的使用场景,如鉴权,流量转发,请求统计等等.

## zuul 的 Filter
Filter是Zuul的核心，用来实现对外服务的控制。Filter的生命周期有4个，分别是“PRE”、“ROUTING”、“POST”、“ERROR”，整个生命周期可以用下图来表示。
![](https://img2018.cnblogs.com/blog/1219190/201908/1219190-20190816130023348-259888220.png)
Zuul大部分功能都是通过过滤器来实现的，这些过滤器类型对应于请求的典型生命周期。

- PRE： 这种过滤器在请求被路由之前调用。我们可利用这种过滤器实现身份验证、在集群中选择请求的微服务、记录调试信息等。
- ROUTING：这种过滤器将请求路由到微服务。这种过滤器用于构建发送给微服务的请求，并使用Apache HttpClient或Netfilx Ribbon请求微服务。
- POST：这种过滤器在路由到微服务以后执行。这种过滤器可用来为响应添加标准的HTTP Header、收集统计信息和指标、将响应从微服务发送给客户端等。
- ERROR：在其他阶段发生错误时执行该过滤器。 除了默认的过滤器类型，Zuul还允许我们创建自定义的过滤器类型。例如，我们可以定制一种STATIC类型的过滤器，直接在Zuul中生成响应，而不将请求转发到后端的微服务。

## zuul中默认的filter

![](https://img2018.cnblogs.com/blog/1219190/201908/1219190-20190816130936722-2054387257.png)

## 自定义Filter

如果要自定义Filter,需要继承ZuulFiilter类,并实现以下方法:
```java
public class MyFilter extends ZuulFilter {
    @Override
    String filterType() {
        return "pre"; //定义filter的类型，有pre、route、post、error四种
    }

    @Override
    int filterOrder() {
        return 10; //定义filter的顺序，数字越小表示顺序越高，越先执行
    }

    @Override
    boolean shouldFilter() {
        return true; //表示是否需要执行该filter，true表示执行，false表示不执行
    }

    @Override
    Object run() {
        return null; //filter需要执行的具体操作
    }
}
```
接下来我们来自定义一个Filter,让请求必须带上token
```java
public class TokenFilter extends ZuulFilter {

    private final Logger logger = LoggerFactory.getLogger(TokenFilter.class);

    @Override
    public String filterType() {
        return "pre"; // 可以在请求被路由之前调用
    }

    @Override
    public int filterOrder() {
        return 0; // filter执行顺序，通过数字指定 ,优先级为0，数字越大，优先级越低
    }

    @Override
    public boolean shouldFilter() {
        return true; // 是否执行该过滤器，此处为true，说明需要过滤
    }

    @Override
    public Object run() throws ZuulException {

        RequestContext ctx = RequestContext.getCurrentContext();
        HttpServletRequest request = ctx.getRequest();

        logger.info("--->>> TokenFilter {},{}", request.getMethod(), request.getRequestURL().toString());

        String token = request.getParameter("token");

        if (StringUtils.isNotBlank(token)) {
            ctx.setSendZuulResponse(true);  //对请求进行路由
            ctx.setResponseStatusCode(200);
            ctx.set("isSuccess", true);
        } else {
            ctx.setSendZuulResponse(false); //不对请求进行路由
            ctx.setResponseStatusCode(400);
            ctx.setResponseBody("token is empty");
            ctx.set("isSuccess", false);
        }

        return null;
    }
}
```
将请求添加到拦截列队
```java
@SpringBootApplication
@EnableZuulProxy
@EnableDiscoveryClient
public class ZuulApplication {

    @Bean
    public TokenFilter tokenFilter() {
        return new TokenFilter();
    }

    public static void main(String[] args) {
        SpringApplication.run(ZuulApplication.class, args);
    }

}
```
然后我们依次启动discovery,producer和zuul,
访问`http://localhost:8888/producer/hello?name=xingyys`返回`token is empty`.
访问`http://localhost:8888/producer/hello?name=xingyys&token=xingyys`, 返回`Hello xingyys !`,说明Filter已经生效了.

由此看出,`PRE`运行在请求前,利用它我们可以结合一个鉴权的第三方库作用户验证.

## 路由的熔断
有时当请求错误时,我们不希望将异常直接抛给最外层,而是让错误降一级,zuul就提供了此功能,当后端服务异常时,抛出我们预设的信息.
zuul使用fallback实现异常的降级,通过自定义的fallback方法,并且将其指定给某个route来实现该route访问出问题的熔断处理。主要继承ZuulFallbackProvider接口来实现，ZuulFallbackProvider默认有两个方法，一个用来指明熔断拦截哪个服务，一个定制返回内容。
```
public interface ZuulFallbackProvider {
   /**
	 * The route this fallback will be used for.
	 * @return The route the fallback will be used for.
	 */
	public String getRoute();

	/**
	 * Provides a fallback response.
	 * @return The fallback response.
	 */
	public ClientHttpResponse fallbackResponse();
}
```
实现类通过实现getRoute方法，告诉Zuul它是负责哪个route定义的熔断。而fallbackResponse方法则是告诉 Zuul 断路出现时，它会提供一个什么返回值来处理请求。

后来Spring又扩展了此类，丰富了返回方式，在返回的内容中添加了异常信息，因此最新版本建议直接继承类`FallbackProvider` 。

我们以上面的producer服务为例，定制它的熔断返回内容。
```java
@Component
public class ProducerFallBack implements FallbackProvider {

    private final Logger logger = LoggerFactory.getLogger(FallbackProvider.class);

    // 指定要处理的service
    @Override
    public String getRoute() {
        return "producer";
    }

    public ClientHttpResponse fallbackResponse() {
        return new ClientHttpResponse() {
            @Override
            public HttpStatus getStatusCode() throws IOException {
                return HttpStatus.OK;
            }

            @Override
            public int getRawStatusCode() throws IOException {
                return 200;
            }

            @Override
            public String getStatusText() throws IOException {
                return "OK";
            }

            @Override
            public void close() {

            }

            @Override
            public InputStream getBody() throws IOException {
                return new ByteArrayInputStream("The service is unavailable".getBytes());
            }

            @Override
            public HttpHeaders getHeaders() {
                HttpHeaders headers = new HttpHeaders();
                headers.setContentType(MediaType.APPLICATION_JSON);
                return headers;
            }
        };
    }

    @Override
    public ClientHttpResponse fallbackResponse(String route, Throwable cause) {
        if (cause != null && cause.getCause() != null)  {
            String reason = cause.getCause().getMessage();
            logger.info("Exception {}", reason);
        }
        return fallbackResponse();
    }
}
```
重新编译启动zuul后,我们关闭producer,并访问`http://localhost:8888/producer/hello?name=xingyys&token=xingyys`, 返回`The service is unavailable`.可见错误处理成功了.
Zuul 目前只支持服务级别的熔断，不支持具体到某个URL进行熔断。
> 注: 以上大量出自 http://www.ityouknow.com

## 路由重试
由于本系列的开发环境是spring boot 2.x的, 而zuul还是1.x版本的,以上的功能还是可以使用的.但是`路由重试`功能经测试不能生效,所以就展示配置和代码.

### 依赖
```
<dependency>
	<groupId>org.springframework.retry</groupId>
	<artifactId>spring-retry</artifactId>
</dependency>
```

### 配置
```
#是否开启重试功能
zuul.retryable=true
#对当前服务的重试次数
ribbon.MaxAutoRetries=2
#切换相同Server的次数
ribbon.MaxAutoRetriesNextServer=0
```
spring cloud 2.x版本已经拥有自己的gateway组件了,所以下一篇我们就来尝试spring cloud gateway
