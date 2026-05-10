package com.streamlist.media.client;

import com.streamlist.media.model.MediaInfo;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestTemplate;
import org.springframework.web.util.UriComponentsBuilder;

import java.net.URI;

@Component
public class ImdbClient {

    private final RestTemplate restTemplate;
    private final String baseUrl;
    private final String apiKey;

    public ImdbClient(RestTemplate restTemplate,
                      @Value("${providers.imdb.base-url}") String baseUrl,
                      @Value("${providers.imdb.api-key}") String apiKey) {
        this.restTemplate = restTemplate;
        this.baseUrl = baseUrl;
        this.apiKey = apiKey;
    }

    public MediaInfo lookup(String mediaId) {
        URI uri = UriComponentsBuilder.fromUriString(baseUrl)
                .pathSegment("v2", "title", mediaId)
                .queryParam("apikey", apiKey)
                .build()
                .toUri();
        return restTemplate.getForObject(uri, MediaInfo.class);
    }
}
