package com.streamlist.media.model;

public class Rating {

    private String provider;
    private double score;
    private long sampleSize;

    public Rating() {
    }

    public Rating(String provider, double score, long sampleSize) {
        this.provider = provider;
        this.score = score;
        this.sampleSize = sampleSize;
    }

    public String getProvider() { return provider; }
    public void setProvider(String provider) { this.provider = provider; }

    public double getScore() { return score; }
    public void setScore(double score) { this.score = score; }

    public long getSampleSize() { return sampleSize; }
    public void setSampleSize(long sampleSize) { this.sampleSize = sampleSize; }
}
