package com.nexus.finance.model;

import jakarta.persistence.*;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

/**
 * Immutable ledger record persisted to the {@code transactions} table for every
 * balance-mutating operation executed by the Nexus Finance wallet engine.
 *
 * <p>Transaction types:</p>
 * <ul>
 *   <li>{@code CREDIT}       — funds added to the wallet (Add Cash)</li>
 *   <li>{@code DEBIT}        — funds deducted via a Mini-App payment</li>
 *   <li>{@code TRANSFER_OUT} — outgoing peer-to-peer transfer (sender side)</li>
 *   <li>{@code TRANSFER_IN}  — incoming peer-to-peer transfer (recipient side)</li>
 * </ul>
 */
@Entity
@Table(name = "transactions", indexes = {
        @Index(name = "idx_txn_username",  columnList = "username"),
        @Index(name = "idx_txn_timestamp", columnList = "timestamp")
})
public class Transaction {

    @Id
    @Column(name = "txn_id", length = 64, nullable = false, updatable = false)
    private String txnId;

    /** The wallet owner this transaction belongs to. */
    @Column(name = "username", nullable = false)
    private String username;

    /**
     * Semantic type of the ledger event.
     * Stored as a VARCHAR so the column is human-readable in Postgres.
     */
    @Enumerated(EnumType.STRING)
    @Column(name = "type", length = 20, nullable = false)
    private TransactionType type;

    /** ISO-4217 currency code (USD, EUR, GBP). */
    @Column(name = "currency", length = 10, nullable = false)
    private String currency;

    /** Absolute amount — always positive. */
    @Column(name = "amount", precision = 18, scale = 2, nullable = false)
    private BigDecimal amount;

    /** Snapshot of the user's balance in this currency AFTER the operation. */
    @Column(name = "balance_after", precision = 18, scale = 2)
    private BigDecimal balanceAfter;

    /**
     * Optional contextual label:
     * – For DEBIT:        the miniAppId (e.g. "gold-app")
     * – For TRANSFER_*:  the counterparty username
     * – For CREDIT:      "wallet-topup"
     */
    @Column(name = "counterparty", length = 128)
    private String counterparty;

    /** Human-readable description shown in the Flutter UI. */
    @Column(name = "description", length = 256)
    private String description;

    /** UTC epoch the record was created. Immutable after insert. */
    @Column(name = "timestamp", nullable = false, updatable = false)
    private Instant timestamp;

    // -------------------------------------------------------------------------
    // Constructors
    // -------------------------------------------------------------------------

    /** Required by JPA — do not call directly. */
    public Transaction() {
    }

    /**
     * Factory constructor used by {@link com.nexus.finance.controller.WalletController}.
     */
    public Transaction(String username,
                       TransactionType type,
                       String currency,
                       BigDecimal amount,
                       BigDecimal balanceAfter,
                       String counterparty,
                       String description) {
        this.txnId        = "TXN-" + UUID.randomUUID().toString().replace("-", "").substring(0, 12).toUpperCase();
        this.username     = username;
        this.type         = type;
        this.currency     = currency.toUpperCase();
        this.amount       = amount;
        this.balanceAfter = balanceAfter;
        this.counterparty = counterparty;
        this.description  = description;
        this.timestamp    = Instant.now();
    }

    // -------------------------------------------------------------------------
    // Getters (no setters — record is immutable post-insert)
    // -------------------------------------------------------------------------

    public String getTxnId()              { return txnId;        }
    public String getUsername()           { return username;     }
    public TransactionType getType()      { return type;         }
    public String getCurrency()           { return currency;     }
    public BigDecimal getAmount()         { return amount;       }
    public BigDecimal getBalanceAfter()   { return balanceAfter; }
    public String getCounterparty()       { return counterparty; }
    public String getDescription()        { return description;  }
    public Instant getTimestamp()         { return timestamp;    }

    // -------------------------------------------------------------------------
    // Enum
    // -------------------------------------------------------------------------

    public enum TransactionType {
        CREDIT,
        DEBIT,
        TRANSFER_OUT,
        TRANSFER_IN
    }
}
