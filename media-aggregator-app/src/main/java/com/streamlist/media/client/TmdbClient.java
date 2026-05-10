package com.streamlist.media.client;

import com.streamlist.media.model.MediaInfo;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestTemplate;
import org.springframework.web.util.UriComponentsBuilder;

import java.net.URI;

@Component
public class TmdbClient {

    private final RestTemplate restTemplate;
    private final String baseUrl;
    private final String apiKey;

    public TmdbClient(RestTemplate restTemplate,
                      @Value("${providers.tmdb.base-url}") String baseUrl,
                      @Value("${providers.tmdb.api-key}") String apiKey) {
        this.restTemplate = restTemplate;
        this.baseUrl = baseUrl;
        this.apiKey = apiKey;
    }

    public MediaInfo lookup(String mediaId) {
        URI uri = UriComponentsBuilder.fromUriString(baseUrl)
                .pathSegment("v3", "title", mediaId)
                .queryParam("api_key", apiKey)
                .build()
                .toUri();
        return restTemplate.getForObject(uri, MediaInfo.class);
    }

    public ResponseEntity<MediaInfo[]> search(String query) {
        URI uri = UriComponentsBuilder.fromUriString(baseUrl)
                .pathSegment("v3", "search")
                .queryParam("api_key", apiKey)
                .queryParam("q", query)
                .build()
                .toUri();
        return restTemplate.getForEntity(uri, MediaInfo[].class);
    }
}
