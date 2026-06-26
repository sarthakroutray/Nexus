package com.nexus.finance.repository;

import com.nexus.finance.model.Transaction;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

/**
 * Data-access layer for the {@link Transaction} ledger table.
 *
 * <p>All queries are scoped to a single {@code username} and ordered
 * newest-first so the Flutter UI can render them in chronological
 * descending order without any client-side sorting.</p>
 */
@Repository
public interface TransactionRepository extends JpaRepository<Transaction, String> {

    /**
     * Fetches the most recent {@code n} transactions for a given user,
     * ordered by timestamp descending.
     *
     * @param username the wallet owner
     * @param pageable use {@code PageRequest.of(0, n)} to cap the result set
     * @return immutable list of matching transactions, newest first
     */
    List<Transaction> findByUsernameOrderByTimestampDesc(String username, Pageable pageable);
}
