package com.nexus.finance.model;

/**
 * Represents a lightweight Mini-App registered in the Nexus Finance ecosystem.
 * Written with explicit constructors and getters/setters to ensure maximum
 * compiler compatibility without requiring Lombok annotation processors.
 */
public class MiniApp {
    private String id;
    private String displayName;
    private String description;
    private String iconUrl;
    private String entryUrl;      // Runtime URL exposed to the Flutter WebView
    private String version;
    private boolean active;

    public MiniApp() {}

    public MiniApp(String id, String displayName, String description, String iconUrl, String entryUrl, String version, boolean active) {
        this.id = id;
        this.displayName = displayName;
        this.description = description;
        this.iconUrl = iconUrl;
        this.entryUrl = entryUrl;
        this.version = version;
        this.active = active;
    }

    public String getId() {
        return id;
    }

    public void setId(String id) {
        this.id = id;
    }

    public String getDisplayName() {
        return displayName;
    }

    public void setDisplayName(String displayName) {
        this.displayName = displayName;
    }

    public String getDescription() {
        return description;
    }

    public void setDescription(String description) {
        this.description = description;
    }

    public String getIconUrl() {
        return iconUrl;
    }

    public void setIconUrl(String iconUrl) {
        this.iconUrl = iconUrl;
    }

    public String getEntryUrl() {
        return entryUrl;
    }

    public void setEntryUrl(String entryUrl) {
        this.entryUrl = entryUrl;
    }

    public String getVersion() {
        return version;
    }

    public void setVersion(String version) {
        this.version = version;
    }

    public boolean isActive() {
        return active;
    }

    public void setActive(boolean active) {
        this.active = active;
    }
}
