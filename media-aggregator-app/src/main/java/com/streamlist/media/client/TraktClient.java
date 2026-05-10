package com.streamlist.media.client;

import com.streamlist.media.model.CorrectionRequest;
import com.streamlist.media.model.MediaInfo;
import com.streamlist.media.model.Rating;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestTemplate;
import org.springframework.web.util.UriComponentsBuilder;

import java.net.URI;

@Component
public class TraktClient {

    private final RestTemplate restTemplate;
    private final String baseUrl;
    private final String clientId;

    public TraktClient(RestTemplate restTemplate,
                       @Value("${providers.trakt.base-url}") String baseUrl,
                       @Value("${providers.trakt.client-id}") String clientId) {
        this.restTemplate = restTemplate;
        this.baseUrl = baseUrl;
        this.clientId = clientId;
    }

    public ResponseEntity<MediaInfo> fetch(String mediaId) {
        URI uri = UriComponentsBuilder.fromUriString(baseUrl)
                .pathSegment("v1", "shows", mediaId)
                .build()
                .toUri();
        return restTemplate.getForEntity(uri, MediaInfo.class);
    }

    public ResponseEntity<String> submitCorrection(CorrectionRequest request) {
        URI uri = UriComponentsBuilder.fromUriString(baseUrl)
                .pathSegment("v1", "corrections")
                .build()
                .toUri();

        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.APPLICATION_JSON);
        headers.add("X-Trakt-Client-Id", clientId);

        return restTemplate.postForEntity(uri, new HttpEntity<>(request, headers), String.class);
    }

    public Rating snapshotRating(String mediaId, Rating rating) {
        URI uri = UriComponentsBuilder.fromUriString(baseUrl)
                .pathSegment("v1", "ratings", mediaId)
                .build()
                .toUri();

        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.APPLICATION_JSON);
        headers.add("X-Trakt-Client-Id", clientId);

        return restTemplate.postForObject(uri, new HttpEntity<>(rating, headers), Rating.class);
    }

    public void deleteCorrection(String correctionId) {
        URI uri = UriComponentsBuilder.fromUriString(baseUrl)
                .pathSegment("v1", "corrections", correctionId)
                .build()
                .toUri();
        restTemplate.delete(uri);
    }
}
