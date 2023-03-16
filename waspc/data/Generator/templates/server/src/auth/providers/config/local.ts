{{={= =}=}}

import { Router } from "express";

import login from "../local/login.js";
import signup from "../local/signup.js";
import { ProviderConfig } from "../types.js";

const config: ProviderConfig = {
    id: "{= providerId =}",
    displayName: "{= displayName =}",
    createRouter() {
        const router = Router();

        router.post('/login', login);
        router.post('/signup', signup);

        return router;
    },
}

export default config;
