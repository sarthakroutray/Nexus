package com.nexus.finance.model;

import jakarta.persistence.CollectionTable;
import jakarta.persistence.Column;
import jakarta.persistence.ElementCollection;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.MapKeyColumn;
import jakarta.persistence.Table;

import java.math.BigDecimal;
import java.util.HashMap;
import java.util.Map;

@Entity
@Table(name = "users")
public class User {

    @Id
    @Column(name = "username", nullable = false, unique = true)
    private String username;

    @Column(name = "password", nullable = false)
    private String password;

    @ElementCollection(fetch = FetchType.EAGER)
    @CollectionTable(name = "user_balances", joinColumns = @JoinColumn(name = "username"))
    @MapKeyColumn(name = "currency")
    @Column(name = "balance")
    private Map<String, BigDecimal> balances = new HashMap<>();

    // Default constructor for JPA
    public User() {
    }

    // All-args constructor for seeding/creation
    public User(String username, String password, BigDecimal usdBalance) {
        this.username = username;
        this.password = password;
        this.balances.put("USD", usdBalance);
        this.balances.put("EUR", usdBalance.multiply(new BigDecimal("0.92")).setScale(2, java.math.RoundingMode.HALF_UP));
        this.balances.put("GBP", usdBalance.multiply(new BigDecimal("0.78")).setScale(2, java.math.RoundingMode.HALF_UP));
    }

    // Getters and Setters
    public String getUsername() {
        return username;
    }

    public void setUsername(String username) {
        this.username = username;
    }

    public String getPassword() {
        return password;
    }

    public void setPassword(String password) {
        this.password = password;
    }

    // Kept for backward compatibility (returns USD)
    public BigDecimal getBalance() {
        return getBalance("USD");
    }

    // Kept for backward compatibility (sets USD)
    public void setBalance(BigDecimal balance) {
        setBalance("USD", balance);
    }

    // Proper multi-currency accessors
    public BigDecimal getBalance(String currency) {
        if (currency == null) return BigDecimal.ZERO;
        return balances.getOrDefault(currency.toUpperCase(), BigDecimal.ZERO);
    }

    public void setBalance(String currency, BigDecimal balance) {
        if (currency != null) {
            balances.put(currency.toUpperCase(), balance);
        }
    }

    public Map<String, BigDecimal> getBalances() {
        return balances;
    }

    public void setBalances(Map<String, BigDecimal> balances) {
        this.balances = balances;
    }
}
