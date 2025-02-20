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


require_once __DIR__ . '/init.php';
use WHMCS\Database\Capsule;

// Configuration
$customFieldId = 10; // Change this to match your VAT custom field ID

// Configuration: Note templates for EU and GB
$noteTemplateEU = "VAT (0%): 0.00 {currency}\nDomestic turnover is not taxable, your VAT registration number is: {vat}.\nThis transaction complies with Article 196 of the EU VAT Directive 2006/112/EC (Reverse Charge). Under this mechanism, the buyer is responsible for reporting VAT in their respective EU country.";

$noteTemplateGB = "No VAT charged under UK reverse charge rules. Your VAT registration number is: {vat}.\n This transaction complies with the UK VAT Act 1994 and post-Brexit domestic reverse charge regulations. Under these rules, the buyer is required to self-account for VAT.";

// Fetch company country code from WHMCS settings
$companyCountryCode = Capsule::table('tblconfiguration')
    ->where('setting', 'TaxEUHomeCountry')
    ->value('value');

if (!$companyCountryCode) {
    echo "Error: Failed to retrieve company country code from TaxEUHomeCountry.\n";
    exit;
}

// Array of EU country codes (including GB for B2B rules)
$euCountries = ['AT', 'BE', 'BG', 'CY', 'CZ', 'DE', 'DK', 'EE', 'ES', 'FI', 'FR', 'GR', 'HR', 'HU', 'IE', 'IT', 'LT', 'LU', 'LV', 'MT', 'NL', 'PL', 'PT', 'RO', 'SE', 'SI', 'SK', 'GB'];

// Ensure $euCountries is an array
if (!is_array($euCountries) || empty($euCountries)) {
    echo "Error: Invalid EU country list.\n";
    exit;
}

try {
    echo "Starting invoice updates...\n";

    $invoices = Capsule::table('tblinvoices')
        ->whereIn('status', ['Unpaid', 'Paid'])
        ->get();

    foreach ($invoices as $invoice) {
        $invoiceId = $invoice->id;
        $userId = $invoice->userid;

        // Fetch client details
        $clientDetails = Capsule::table('tblclients')
            ->where('id', $userId)
            ->first(['country', 'taxexempt', 'currency']);

        if (!$clientDetails) {
            echo "No client found for User ID: $userId. Skipping invoice ID: $invoiceId.\n";
            continue;
        }

        $clientCountry = $clientDetails->country;
        $isTaxExempt = $clientDetails->taxexempt;
        $currencyId = $clientDetails->currency;

        // **EARLY CHECK**: If client is not in EU or GB, skip now
        if (!in_array($clientCountry, $euCountries)) {
            echo "User ID: $userId (Country: $clientCountry) not in EU/GB. Skipping invoice ID: $invoiceId.\n";
            continue;
        }

        // Retrieve VAT number from custom field only if in EU/GB
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

        // Fetch the currency code
        $currency = Capsule::table('tblcurrencies')
            ->where('id', $currencyId)
            ->value('code');

        // Log details for debugging
        echo "Checking invoice ID: $invoiceId, User ID: $userId, Country: $clientCountry, Tax Exempt: $isTaxExempt, VAT Number: $vatNumber, Currency: $currency\n";

        // Process conditions after confirming EU/GB membership
        if (
            $clientCountry !== $companyCountryCode &&
            !empty($isTaxExempt) &&
            !empty($vatNumber)
        ) {
            // Use different note templates for EU and GB
            $note = ($clientCountry === 'GB')
                ? str_replace(['{currency}', '{vat}'], [$currency, $vatNumber], $noteTemplateGB)
                : str_replace(['{currency}', '{vat}'], [$currency, $vatNumber], $noteTemplateEU);

            // Update the invoice notes
            Capsule::table('tblinvoices')
                ->where('id', $invoiceId)
                ->update(['notes' => $note]);

            echo "Updated invoice ID: $invoiceId with reverse charge note.\n";
        } else {
            echo "Conditions not met for invoice ID: $invoiceId. Skipping.\n";
        }
    }

    echo "Invoice updates completed.\n";

} catch (\Exception $e) {
    echo "Error: " . $e->getMessage() . "\n";
}
