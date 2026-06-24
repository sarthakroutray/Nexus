package com.nexus.finance.repository;

import com.nexus.finance.model.User;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

/**
 * Data access repository for the {@link User} entity, backed by the {@code users} table
 * in PostgreSQL.
 *
 * <p>This is the single persistence point for all wallet operations in the Nexus Finance
 * ecosystem. Username is used as the natural primary key ({@link String}) so that
 * authentication, balance inquiries, fund deductions, credits, and transfers all resolve
 * directly without requiring synthetic IDs.</p>
 *
 * <p><b>Dependencies:</b></p>
 * <ul>
 *   <li>{@link com.nexus.finance.controller.AuthController AuthController} — login and
 *       registration lookups</li>
 *   <li>{@link com.nexus.finance.controller.WalletController WalletController} — balance
 *       reads, deductions, credits, and transfers</li>
 *   <li>{@link com.nexus.finance.security.DataSeeder DataSeeder} — initial test-user seeding
 *       on application startup</li>
 * </ul>
 *
 * <p><b>Design note:</b> No custom query methods are declared here. All current access
 * patterns are satisfied by {@link JpaRepository}'s built-in {@code findById},
 * {@code existsById}, and {@code save} operations. If query complexity grows (e.g.,
 * paginated transaction history, role-based lookups), add derived query methods or
 * {@code @Query} annotations in this interface rather than introducing a separate DAO
 * layer.</p>
 *
 * @see User
 * @see com.nexus.finance.controller.AuthController
 * @see com.nexus.finance.controller.WalletController
 * @see com.nexus.finance.security.DataSeeder
 */
@Repository
public interface UserRepository extends JpaRepository<User, String> {
}
