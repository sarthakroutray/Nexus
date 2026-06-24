package com.nexus.finance.controller;

import com.nexus.finance.model.MiniApp;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

/**
 * Registry API for the Host App to discover available Mini-Apps.
 */
@CrossOrigin(origins = "*")
@RestController
@RequestMapping("/api/v1/registry")
public class MiniAppRegistryController {

    /**
     * Returns a list of Mini-App metadata.
     * The entryUrl of each app is dynamically resolved to match the incoming request's host IP.
     */
    @GetMapping("/mini-apps")
    public List<MiniApp> getMiniApps(HttpServletRequest request) {
        String host = request.getServerName(); // Resolves to localhost, 10.0.2.2, or LAN IP
        
        String goldUrl = "http://" + host + ":4321";
        String insureUrl = "http://" + host + ":4322";
        String splitUrl = "http://" + host + ":4323";

        return List.of(
                new MiniApp(
                        "gold-app",
                        "Nexus Digital Gold",
                        "Invest in fractional digital gold backed by real reserves.",
                        "https://cdn-icons-png.flaticon.com/512/2489/2489756.png",
                        goldUrl,
                        "1.0.0",
                        true
                ),
                new MiniApp(
                        "insure-app",
                        "InsureMe Micro-Insurance",
                        "Protect your travels. Get instant payout coverage for flight delays.",
                        "https://cdn-icons-png.flaticon.com/512/1063/1063376.png",
                        insureUrl,
                        "1.0.0",
                        true
                ),
                new MiniApp(
                        "split-app",
                        "Split-It Bill Splitter",
                        "Easily divide restaurant bills and settle your share with friends.",
                        "https://cdn-icons-png.flaticon.com/512/9638/9638101.png",
                        splitUrl,
                        "1.0.0",
                        true
                )
        );
    }
}
