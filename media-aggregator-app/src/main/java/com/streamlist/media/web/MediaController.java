package com.streamlist.media.web;

import com.streamlist.media.model.MediaInfo;
import com.streamlist.media.model.Rating;
import com.streamlist.media.service.MetadataAggregator;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RestController
@RequestMapping("/api/media")
public class MediaController {

    private final MetadataAggregator aggregator;

    public MediaController(MetadataAggregator aggregator) {
        this.aggregator = aggregator;
    }

    @GetMapping("/{id}")
    public ResponseEntity<MediaInfo> get(@PathVariable String id) {
        MediaInfo info = aggregator.aggregate(id);
        return ResponseEntity.ok(info);
    }

    @GetMapping("/search")
    public ResponseEntity<List<MediaInfo>> search(@RequestParam("q") String query) {
        return ResponseEntity.ok(aggregator.search(query));
    }

    @GetMapping("/{id}/ratings")
    public ResponseEntity<List<Rating>> ratings(@PathVariable String id) {
        return ResponseEntity.ok(aggregator.ratingsFor(id));
    }
}
