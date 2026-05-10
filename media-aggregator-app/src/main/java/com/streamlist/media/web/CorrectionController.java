package com.streamlist.media.web;

import com.streamlist.media.model.CorrectionRequest;
import com.streamlist.media.service.MetadataAggregator;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/corrections")
public class CorrectionController {

    private final MetadataAggregator aggregator;

    public CorrectionController(MetadataAggregator aggregator) {
        this.aggregator = aggregator;
    }

    @PostMapping
    public ResponseEntity<Void> submit(@RequestBody CorrectionRequest request) {
        boolean accepted = aggregator.submitCorrection(request);
        return accepted ? ResponseEntity.accepted().build() : ResponseEntity.unprocessableEntity().build();
    }
}
