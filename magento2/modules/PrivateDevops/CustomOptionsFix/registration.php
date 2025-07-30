<?php
/**
 * Custom Options Fix Module
 * Copyright (c) 2024 Private DevOps LTD. All rights reserved.
 * https://privatedevops.com
 */

use Magento\Framework\Component\ComponentRegistrar;
ComponentRegistrar::register(
    ComponentRegistrar::MODULE,
    'PrivateDevops_CustomOptionsFix',
    __DIR__
);
