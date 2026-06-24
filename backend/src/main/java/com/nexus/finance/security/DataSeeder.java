package com.nexus.finance.security;

import com.nexus.finance.model.User;
import com.nexus.finance.repository.UserRepository;
import org.mindrot.jbcrypt.BCrypt;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.CommandLineRunner;
import org.springframework.stereotype.Component;

import java.math.BigDecimal;

@Component
public class DataSeeder implements CommandLineRunner {

    @Autowired
    private UserRepository userRepository;

    @Override
    public void run(String... args) throws Exception {
        // Seed default test user: user-001
        if (!userRepository.existsById("user-001")) {
            String defaultHashed = BCrypt.hashpw("password123", BCrypt.gensalt());
            userRepository.save(new User("user-001", defaultHashed, new BigDecimal("1500.00")));
            System.out.println("DataSeeder: Seeded user-001 with default balance $1500.00");
        }

        // Seed default developer user: sarthak
        if (!userRepository.existsById("sarthak")) {
            String sarthakHashed = BCrypt.hashpw("password123", BCrypt.gensalt());
            userRepository.save(new User("sarthak", sarthakHashed, new BigDecimal("1500.00")));
            System.out.println("DataSeeder: Seeded sarthak with default balance $1500.00");
        }
    }
}
