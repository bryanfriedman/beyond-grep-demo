package com.streamlist.media.model;

public class CorrectionRequest {

    private String mediaId;
    private String field;
    private String suggestedValue;
    private String submitterEmail;

    public CorrectionRequest() {
    }

    public String getMediaId() { return mediaId; }
    public void setMediaId(String mediaId) { this.mediaId = mediaId; }

    public String getField() { return field; }
    public void setField(String field) { this.field = field; }

    public String getSuggestedValue() { return suggestedValue; }
    public void setSuggestedValue(String suggestedValue) { this.suggestedValue = suggestedValue; }

    public String getSubmitterEmail() { return submitterEmail; }
    public void setSubmitterEmail(String submitterEmail) { this.submitterEmail = submitterEmail; }
}
