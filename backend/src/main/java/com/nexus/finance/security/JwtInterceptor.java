package com.nexus.finance.security;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpMethod;
import org.springframework.stereotype.Component;
import org.springframework.web.servlet.HandlerInterceptor;

import java.io.IOException;

@Component
public class JwtInterceptor implements HandlerInterceptor {

    @Autowired
    private JwtUtil jwtUtil;

    @Override
    public boolean preHandle(HttpServletRequest request, HttpServletResponse response, Object handler) throws Exception {
        // Allow CORS preflight requests
        if (HttpMethod.OPTIONS.name().equalsIgnoreCase(request.getMethod())) {
            return true;
        }

        String authHeader = request.getHeader("Authorization");
        if (authHeader == null || !authHeader.startsWith("Bearer ")) {
            sendUnauthorizedError(response, "Missing or malformed Authorization header. Expected: Bearer <token>");
            return false;
        }

        String token = authHeader.substring(7);
        try {
            String username = jwtUtil.validateTokenAndGetUsername(token);
            // Set the authenticated user in the request attributes
            request.setAttribute("authenticatedUser", username);
            return true;
        } catch (Exception e) {
            sendUnauthorizedError(response, "Invalid, expired, or tampered JWT token: " + e.getMessage());
            return false;
        }
    }

    private void sendUnauthorizedError(HttpServletResponse response, String message) throws IOException {
        response.setContentType("application/json");
        response.setStatus(HttpServletResponse.SC_UNAUTHORIZED);
        response.getWriter().write(String.format(
                "{\"success\": false, \"message\": \"%s\", \"error\": \"Unauthorized\"}",
                message.replace("\"", "\\\"")
        ));
    }
}
