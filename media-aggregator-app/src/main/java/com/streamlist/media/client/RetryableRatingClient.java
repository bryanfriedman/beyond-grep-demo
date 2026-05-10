package com.streamlist.media.client;

import com.streamlist.media.model.Rating;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.ResponseEntity;
import org.springframework.retry.annotation.Backoff;
import org.springframework.retry.annotation.Retryable;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClientException;
import org.springframework.web.client.RestTemplate;
import org.springframework.web.util.UriComponentsBuilder;

import java.net.URI;

/**
 * Wraps the upstream ratings endpoint with declarative retry semantics.
 * The migration recipe should still convert the inner RestTemplate call;
 * the @Retryable annotation is independent of which HTTP client is used.
 */
@Component
public class RetryableRatingClient {

    private final RestTemplate providerRestTemplate;
    private final String baseUrl;

    public RetryableRatingClient(@Qualifier("providerRestTemplate") RestTemplate providerRestTemplate,
                                 @Value("${providers.tmdb.base-url}") String baseUrl) {
        this.providerRestTemplate = providerRestTemplate;
        this.baseUrl = baseUrl;
    }

    @Retryable(
            retryFor = RestClientException.class,
            maxAttemptsExpression = "${ratings.retry.max-attempts}",
            backoff = @Backoff(delayExpression = "${ratings.retry.backoff-millis}")
    )
    public Rating[] fetchRatings(String mediaId) {
        URI uri = UriComponentsBuilder.fromUriString(baseUrl)
                .pathSegment("v3", "title", mediaId, "ratings")
                .build()
                .toUri();
        ResponseEntity<Rating[]> response = providerRestTemplate.getForEntity(uri, Rating[].class);
        return response.getBody();
    }
}
