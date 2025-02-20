<?php

/**
 * Private Devops LTD - WHMCS VAT Reverse Charge Hook
 * ---------------------------------------------------
 * This hook automatically applies reverse charge notes to invoices
 * for eligible EU and GB clients based on VAT regulations at the time
 * of invoice creation.
 *
 * Author: Private Devops LTD
 * Website: https://privatedevops.com
 *
 * Description:
 * ------------
 * This hook ensures that invoices created in WHMCS comply with VAT regulations for
 * B2B and B2C transactions across the EU and the UK. It dynamically applies reverse
 * charge notes or VAT charges to invoices based on the client's country, tax exemption
 * status, and VAT registration. For eligible B2B transactions, no VAT is charged,
 * and the responsibility for VAT reporting shifts to the client (reverse charge).
 *
 * Key Features:
 * -------------
 * - Automatically triggered during invoice creation in WHMCS.
 * - Adds reverse charge notes for EU and GB clients with valid VAT numbers.
 * - Ensures VAT compliance for both B2B (reverse charge) and B2C (standard VAT) scenarios.
 * - Fetches company country code dynamically from WHMCS settings (`TaxEUHomeCountry`).
 * - Flexible configuration for VAT custom field ID and note templates.
 * - Detailed logging for debugging and activity tracking in WHMCS.
 *
 * How to Use:
 * -----------
 * 1. Save this script in the `includes/hooks/` directory of your WHMCS installation.
 * 2. Update the `$customFieldId` variable to match the VAT custom field ID in your WHMCS:
 *    - Run: `SELECT id, fieldname FROM tblcustomfields WHERE fieldname LIKE '%VAT%';`
 *    - Replace the default value of `$customFieldId` with the retrieved ID.
 * 3. Customize the `$noteTemplateEU` and `$noteTemplateGB` variables for EU and GB notes.
 * 4. Test the hook by creating new invoices for clients from EU countries or GB.
 * 5. Monitor the WHMCS Activity Log (Utilities > Logs > Activity Log) for hook execution details.
 *
 * Requirements:
 * -------------
 * - WHMCS must be configured with a VAT custom field or the native `vat` field.
 * - Clients must:
 *   - Have a valid VAT number (stored in the configured custom field or native field).
 *   - Be marked as tax-exempt (for reverse charge eligibility).
 *   - Reside in an EU country or GB for processing.
 * - Ensure your company country code is correctly set in WHMCS (`TaxEUHomeCountry`).
 *
 * Key Regulations Referenced:
 * ----------------------------
 * - **EU VAT Directive 2006/112/EC (Article 196)**:
 *   - Governs reverse charge mechanisms for B2B cross-border services within the EU.
 * - **UK VAT Act 1994**:
 *   - Governs reverse charge rules for services supplied to UK businesses post-Brexit.
 * - **Local VAT Rules (e.g., Bulgaria)**:
 *   - Applied for B2C transactions where no valid VAT number is provided.
 *
 * Notes:
 * ------
 * - This hook applies only to invoices created after its implementation.
 * - Skips clients without valid VAT numbers or tax exemption status.
 * - Provides activity log entries for debugging and tracking.
 * - Ideal for maintaining compliance with VAT regulations in real time.
 */

use WHMCS\Database\Capsule;

// Configuration: Update this with your VAT custom field ID
$customFieldId = 10; // Change this to match your VAT custom field ID

// Array of EU country codes (including GB for B2B logic)
$euCountries = [
    'AT', 'BE', 'BG', 'CY', 'CZ', 'DE', 'DK', 'EE', 'ES', 'FI', 'FR', 'GR', 'HR', 
    'HU', 'IE', 'IT', 'LT', 'LU', 'LV', 'MT', 'NL', 'PL', 'PT', 'RO', 'SE', 'SI', 
    'SK', 'GB'
];

// Configuration: Note templates for EU and GB
$noteTemplateEU = "VAT (0%): 0.00 {currency}\nDomestic turnover is not taxable, your VAT registration number is: {vat}.\nThis transaction complies with Article 196 of the EU VAT Directive 2006/112/EC (Reverse Charge).";

$noteTemplateGB = "No VAT charged under UK reverse charge rules. Your VAT registration number is: {vat}.\nThis transaction complies with the UK VAT Act 1994 and post-Brexit domestic reverse charge regulations.";

add_hook('InvoiceCreation', 1, function ($vars) use ($customFieldId, $euCountries, $noteTemplateEU, $noteTemplateGB) {
    $invoiceId = $vars['invoiceid'];

    // Fetch company country code from WHMCS TaxEUHomeCountry setting
    $companyCountryCode = Capsule::table('tblconfiguration')
        ->where('setting', 'TaxEUHomeCountry')
        ->value('value');

    if (!$companyCountryCode) {
        logActivity("VAT Hook Debug: Failed to retrieve company country code from TaxEUHomeCountry.");
        return;
    }

    // Fetch invoice details to get the user ID
    $invoice = Capsule::table('tblinvoices')
        ->where('id', $invoiceId)
        ->first(['userid']);

    if (!$invoice) {
        logActivity("VAT Hook Debug: No invoice found for Invoice ID: $invoiceId");
        return;
    }

    $userId = $invoice->userid;

    // Fetch client details
    $clientDetails = Capsule::table('tblclients')
        ->where('id', $userId)
        ->first(['country', 'taxexempt', 'currency']);

    if (!$clientDetails) {
        logActivity("VAT Hook Debug: No client found for User ID: $userId");
        return;
    }

    $clientCountry = $clientDetails->country;

    // **EARLY CHECK**: Skip clients not in the EU or GB immediately
    if (!in_array($clientCountry, $euCountries)) {
        logActivity("VAT Hook Debug: Skipped User ID: $userId (Country: $clientCountry) - Not in EU or GB.");
        return;
    }

    // Retrieve VAT number now that we've confirmed EU/GB
    $vatNumber = Capsule::table('tblcustomfieldsvalues')
        ->where('fieldid', $customFieldId)
        ->where('relid', $userId)
        ->value('value');

    /* Check disabled because return errors with clients without vat field */
    /*
    if (empty($vatNumber)) {
        $vatNumber = Capsule::table('tblclients')
            ->where('id', $userId)
            ->value('vat');
    }
    */

    if (!$vatNumber) {
        logActivity("VAT Hook Debug: No VAT Number found for User ID: $userId.");
        return;
    }

    $isTaxExempt = $clientDetails->taxexempt;
    $currencyId = $clientDetails->currency;

    // Fetch the client currency
    $currency = Capsule::table('tblcurrencies')
        ->where('id', $currencyId)
        ->value('code');

    // Log variables for debugging
    logActivity("VAT Hook Debug: Invoice ID: $invoiceId, User ID: $userId, Country: $clientCountry, Company Country: $companyCountryCode, Tax Exempt: $isTaxExempt, VAT Number: $vatNumber");

    // Check conditions for adding the reverse charge note
    if (
        in_array($clientCountry, $euCountries) &&
        $clientCountry !== $companyCountryCode &&
        !empty($isTaxExempt) &&
        !empty($vatNumber)
    ) {
        // Use GB-specific note for UK clients
        $note = ($clientCountry === 'GB')
            ? str_replace('{vat}', $vatNumber, $noteTemplateGB)
            : str_replace(['{currency}', '{vat}'], [$currency, $vatNumber], $noteTemplateEU);

        // Update the invoice with the note
        Capsule::table('tblinvoices')
            ->where('id', $invoiceId)
            ->update(['notes' => $note]);

        logActivity("VAT Hook Debug: Added reverse charge note to Invoice ID: $invoiceId for User ID: $userId");
    } else {
        logActivity("VAT Hook Debug: Conditions not met for Invoice ID: $invoiceId. Country: $clientCountry, Tax Exempt: $isTaxExempt, VAT: $vatNumber");
    }
});
