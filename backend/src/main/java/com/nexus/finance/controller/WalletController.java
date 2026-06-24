package com.nexus.finance.controller;

import com.nexus.finance.model.User;
import com.nexus.finance.repository.UserRepository;
import org.mindrot.jbcrypt.BCrypt;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.util.Map;

/**
 * Core Wallet Engine backed by PostgreSQL for balance inquiry, deductions, and transfers.
 */
@CrossOrigin(origins = "*")
@RestController
@RequestMapping("/api/v1/wallet")
public class WalletController {

    @Autowired
    private UserRepository userRepository;

    /**
     * Gets a user from database or registers them dynamically with standard starting balance.
     */
    private User getOrCreateUser(String username) {
        return userRepository.findById(username).orElseGet(() -> {
            String defaultHashed = BCrypt.hashpw("password123", BCrypt.gensalt());
            User newUser = new User(username, defaultHashed, new BigDecimal("1500.00"));
            return userRepository.save(newUser);
        });
    }

    @GetMapping("/{userId}/balance")
    public Map<String, Object> getBalance(@PathVariable String userId) {
        User user = getOrCreateUser(userId);
        return Map.of(
                "userId", user.getUsername(),
                "balance", user.getBalance("USD"),
                "balances", user.getBalances(),
                "currency", "USD"
        );
    }

    @PostMapping("/{userId}/deduct")
    public Map<String, Object> deductFunds(
            @PathVariable String userId,
            @RequestBody Map<String, Object> request,
            @RequestAttribute(value = "authenticatedUser", required = false) String authenticatedUser) {

        // Execute deduction for the authenticated user from JWT, falling back to path variable if local/mock testing
        String targetUser = (authenticatedUser != null) ? authenticatedUser : userId;

        BigDecimal requestedAmount = new BigDecimal(request.getOrDefault("amount", "0").toString());
        String currency = request.getOrDefault("currency", "USD").toString().toUpperCase();
        
        User user = getOrCreateUser(targetUser);
        BigDecimal currentBalance = user.getBalance(currency);

        if (currentBalance.compareTo(requestedAmount) < 0) {
            return Map.of(
                    "success", false,
                    "message", "Insufficient funds in " + currency,
                    "remainingBalance", currentBalance,
                    "balances", user.getBalances()
            );
        }

        BigDecimal newBalance = currentBalance.subtract(requestedAmount);
        user.setBalance(currency, newBalance);
        userRepository.save(user);

        return Map.of(
                "success", true,
                "message", "Funds deducted successfully",
                "deductedAmount", requestedAmount,
                "currency", currency,
                "remainingBalance", newBalance,
                "balances", user.getBalances(),
                "txnId", "TXN-SRV-" + java.util.UUID.randomUUID().toString().substring(0, 8).toUpperCase()
        );
    }

    @PostMapping("/{userId}/credit")
    public Map<String, Object> creditFunds(@PathVariable String userId, @RequestBody Map<String, Object> request) {
        BigDecimal requestedAmount = new BigDecimal(request.getOrDefault("amount", "0").toString());
        String currency = request.getOrDefault("currency", "USD").toString().toUpperCase();
        
        User user = getOrCreateUser(userId);
        BigDecimal currentBalance = user.getBalance(currency);
        BigDecimal newBalance = currentBalance.add(requestedAmount);
        user.setBalance(currency, newBalance);
        userRepository.save(user);

        return Map.of(
                "success", true,
                "message", "Funds added successfully",
                "creditedAmount", requestedAmount,
                "currency", currency,
                "remainingBalance", newBalance,
                "balances", user.getBalances()
        );
    }

    @PostMapping("/{userId}/transfer")
    public Map<String, Object> transferFunds(@PathVariable String userId, @RequestBody Map<String, Object> request) {
        BigDecimal requestedAmount = new BigDecimal(request.getOrDefault("amount", "0").toString());
        String recipientId = request.getOrDefault("recipientId", "").toString();
        String currency = request.getOrDefault("currency", "USD").toString().toUpperCase();

        if (recipientId.trim().isEmpty()) {
            return Map.of(
                    "success", false,
                    "message", "Recipient ID is required"
            );
        }

        User sender = getOrCreateUser(userId);
        User recipient = getOrCreateUser(recipientId);
        
        BigDecimal senderBalance = sender.getBalance(currency);

        if (senderBalance.compareTo(requestedAmount) < 0) {
            return Map.of(
                    "success", false,
                    "message", "Insufficient funds for transfer in " + currency,
                    "remainingBalance", senderBalance,
                    "balances", sender.getBalances()
            );
        }

        BigDecimal newSenderBalance = senderBalance.subtract(requestedAmount);
        sender.setBalance(currency, newSenderBalance);
        userRepository.save(sender);

        BigDecimal recipientBalance = recipient.getBalance(currency);
        BigDecimal newRecipientBalance = recipientBalance.add(requestedAmount);
        recipient.setBalance(currency, newRecipientBalance);
        userRepository.save(recipient);

        return Map.of(
                "success", true,
                "message", "Transfer successful",
                "transferredAmount", requestedAmount,
                "currency", currency,
                "recipientId", recipientId,
                "remainingBalance", newSenderBalance,
                "balances", sender.getBalances(),
                "txnId", "TXN-TRF-" + java.util.UUID.randomUUID().toString().substring(0, 8).toUpperCase()
        );
    }
}
