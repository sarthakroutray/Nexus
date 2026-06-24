package com.nexus.finance.security;

import com.auth0.jwt.JWT;
import com.auth0.jwt.algorithms.Algorithm;
import com.auth0.jwt.interfaces.DecodedJWT;
import com.auth0.jwt.interfaces.JWTVerifier;
import org.springframework.stereotype.Component;

import java.util.Date;

@Component
public class JwtUtil {

    private static final String SECRET = "nexus-fintech-super-app-jwt-secure-signing-key-2026";
    private static final String ISSUER = "nexus-auth-service";
    private static final long EXPIRATION_TIME = 3600000; // 1 hour in milliseconds
    private final Algorithm algorithm = Algorithm.HMAC256(SECRET);

    /**
     * Generates a signed JWT token containing the username.
     */
    public String generateToken(String username) {
        return JWT.create()
                .withIssuer(ISSUER)
                .withSubject(username)
                .withIssuedAt(new Date())
                .withExpiresAt(new Date(System.currentTimeMillis() + EXPIRATION_TIME))
                .sign(algorithm);
    }

    /**
     * Validates a JWT token and returns the subject (username) if valid.
     * Throws JWTVerificationException if invalid or expired.
     */
    public String validateTokenAndGetUsername(String token) {
        JWTVerifier verifier = JWT.require(algorithm)
                .withIssuer(ISSUER)
                .build();
        DecodedJWT decodedJWT = verifier.verify(token);
        return decodedJWT.getSubject();
    }
}
