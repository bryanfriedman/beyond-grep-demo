package com.streamlist.media.service;

import com.streamlist.media.client.ImdbClient;
import com.streamlist.media.client.RetryableRatingClient;
import com.streamlist.media.client.TmdbClient;
import com.streamlist.media.client.TraktClient;
import com.streamlist.media.model.CorrectionRequest;
import com.streamlist.media.model.MediaInfo;
import com.streamlist.media.model.Rating;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Service;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collections;
import java.util.List;
import java.util.Objects;

@Service
public class MetadataAggregator {

    private final TmdbClient tmdbClient;
    private final ImdbClient imdbClient;
    private final TraktClient traktClient;
    private final RetryableRatingClient ratingClient;

    public MetadataAggregator(TmdbClient tmdbClient,
                              ImdbClient imdbClient,
                              TraktClient traktClient,
                              RetryableRatingClient ratingClient) {
        this.tmdbClient = tmdbClient;
        this.imdbClient = imdbClient;
        this.traktClient = traktClient;
        this.ratingClient = ratingClient;
    }

    public MediaInfo aggregate(String mediaId) {
        MediaInfo tmdb = tmdbClient.lookup(mediaId);
        MediaInfo imdb = imdbClient.lookup(mediaId);
        ResponseEntity<MediaInfo> traktResponse = traktClient.fetch(mediaId);
        MediaInfo trakt = traktResponse.getBody();
        return merge(mediaId, tmdb, imdb, trakt);
    }

    public List<MediaInfo> search(String query) {
        ResponseEntity<MediaInfo[]> response = tmdbClient.search(query);
        MediaInfo[] body = response.getBody();
        return body == null ? Collections.emptyList() : Arrays.asList(body);
    }

    public List<Rating> ratingsFor(String mediaId) {
        Rating[] body = ratingClient.fetchRatings(mediaId);
        return body == null ? Collections.emptyList() : Arrays.asList(body);
    }

    public boolean submitCorrection(CorrectionRequest request) {
        ResponseEntity<String> response = traktClient.submitCorrection(request);
        return response.getStatusCode().is2xxSuccessful();
    }

    private MediaInfo merge(String mediaId, MediaInfo... candidates) {
        MediaInfo merged = new MediaInfo();
        merged.setId(mediaId);
        List<Rating> allRatings = new ArrayList<>();
        for (MediaInfo c : candidates) {
            if (c == null) continue;
            if (merged.getTitle() == null) merged.setTitle(c.getTitle());
            if (merged.getYear() == null) merged.setYear(c.getYear());
            if (merged.getGenres() == null && c.getGenres() != null) merged.setGenres(c.getGenres());
            if (merged.getSynopsis() == null) merged.setSynopsis(c.getSynopsis());
            if (c.getRatings() != null) allRatings.addAll(c.getRatings());
        }
        merged.setRatings(allRatings);
        merged.setAverageRating(allRatings.stream()
                .filter(Objects::nonNull)
                .mapToDouble(Rating::getScore)
                .average()
                .orElse(0.0));
        return merged;
    }
}
