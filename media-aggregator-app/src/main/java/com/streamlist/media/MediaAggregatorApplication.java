package com.streamlist.media;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.retry.annotation.EnableRetry;

@SpringBootApplication
@EnableRetry
public class MediaAggregatorApplication {

    public static void main(String[] args) {
        SpringApplication.run(MediaAggregatorApplication.class, args);
    }
}
