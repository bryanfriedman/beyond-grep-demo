package com.streamlist.media.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpStatusCode;
import org.springframework.http.client.ClientHttpResponse;
import org.springframework.web.client.DefaultResponseErrorHandler;
import org.springframework.web.client.ResponseErrorHandler;
import org.springframework.web.client.RestTemplate;

import java.io.IOException;

@Configuration
public class HttpClientConfig {

    @Bean
    public RestTemplate restTemplate() {
        return new RestTemplate();
    }

    /**
     * RestTemplate dedicated to upstream provider calls. Uses a custom error
     * handler that classifies 5xx as transient (so the retry layer can kick
     * in) and lets 4xx propagate as a hard error.
     */
    @Bean
    public RestTemplate providerRestTemplate() {
        RestTemplate template = new RestTemplate();
        template.setErrorHandler(new ProviderErrorHandler());
        return template;
    }

    private static class ProviderErrorHandler extends DefaultResponseErrorHandler implements ResponseErrorHandler {
        @Override
        public boolean hasError(ClientHttpResponse response) throws IOException {
            HttpStatusCode status = response.getStatusCode();
            return status.is5xxServerError() || status.is4xxClientError();
        }
    }
}
