# PrivateDevops_CustomOptionsFix for Magento 2

## Overview

**PrivateDevops_CustomOptionsFix** solves a major Magento 2 admin issue:  
Impossible to change sort order of custom option values over several pages in the product edit view.  
This module allows you to set the maximum number of option lines shown per product, so you can drag & drop reorder all options without being limited by pagination.

---

## Features

- Configure the number of custom option lines shown per product in admin
- Instantly sortable, drag & drop for all option values (no more flipping through pages)
- 100% upgrade-safe (no core hacks)
- Works with Magento 2.4.8 and earlier (M2.4.9+ ships with a similar native fix)
- Developed by [Private DevOps LTD](https://privatedevops.com)

---

## Installation

**1. Copy the module**

Place the contents in: app/code/PrivateDevops/CustomOptionsFix

**2. Enable the module**

```sh
php bin/magento module:enable PrivateDevops_CustomOptionsFix
php bin/magento setup:upgrade
php bin/magento cache:flush

If in production mode:

php bin/magento setup:di:compile
php bin/magento setup:static-content:deploy -f

Configuration

After installation, configure in admin:

Stores → Configuration → Catalog → Catalog → Edit Product MAX Option Lines
	•	Default value: 200 (change to any number: 50, 300, 1000, etc.)
	•	Controls the max number of custom option values displayed for each product in the admin.

⸻

Usage
	•	Go to a product with custom options (Admin: Catalog → Products → Edit).
	•	The option values grid will now display as many values as you configured—making all options sortable via drag & drop, with no pagination barrier.

⸻

Troubleshooting
	•	If changes don’t apply, clear browser cache and run php bin/magento cache:flush.
	•	Large values (1000+) may cause slower loading for products with many options.
	•	To verify your setting:
php bin/magento config:show catalog/customoptions/pagesize


Uninstall

php bin/magento module:disable PrivateDevops_CustomOptionsFix
rm -rf app/code/PrivateDevops/CustomOptionsFix
php bin/magento setup:upgrade
php bin/magento cache:flush
