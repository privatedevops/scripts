<?php
/**
 * Private Devops LTD - WHMCS VAT Reverse Charge Update Script
 * --------------------------------------------
 * This script updates old invoices in WHMCS with reverse charge notes
 * for eligible EU clients based on VAT regulations.
 *
 * Author: Private Devops LTD
 * Website: https://privatedevops.com
 * Description: Applies reverse charge notes to invoices for clients
 * who are VAT exempt and within the EU.
 *
 * How to Use:
 * -----------
 * 1. Place this script in the root directory of your WHMCS installation.
 * 2. Access it via a browser or the command line to execute the script.
 * 3. Ensure the correct VAT custom field ID is set in the script (default: 10).
 * 4. Debugging:
 *    - Use output logs to monitor which invoices were updated.
 *    - Errors or skipped invoices will be logged in the output.
 *
 * Notes:
 * ------
 * - Updates are applied only to invoices where conditions are met:
 *   (EU country, tax-exempt status, valid VAT number).
 * - Make sure you back up your database before running the script.
 */

require_once __DIR__ . '/init.php'; // Ensure this path points to your WHMCS init.php file
use WHMCS\Database\Capsule;

// Array of EU country codes
$euCountries = ['AT', 'BE', 'BG', 'CY', 'CZ', 'DE', 'DK', 'EE', 'ES', 'FI', 'FR', 'GR', 'HR', 'HU', 'IE', 'IT', 'LT', 'LU', 'LV', 'MT', 'NL', 'PL', 'PT', 'RO', 'SE', 'SI', 'SK'];

try {
    echo "Starting invoice updates...\n";

    // Fetch all invoices that need to be checked (adjust status filters as needed)
    $invoices = Capsule::table('tblinvoices')
        ->whereIn('status', ['Unpaid', 'Paid']) // Update for these statuses only
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

        // Fetch VAT number from custom field
        $vatNumber = Capsule::table('tblcustomfieldsvalues')
            ->where('fieldid', 10) // Update with your VAT custom field ID
            ->where('relid', $userId)
            ->value('value');

        // Fetch the currency code
        $currency = Capsule::table('tblcurrencies')
            ->where('id', $currencyId)
            ->value('code');

        // Debugging output
        echo "Checking invoice ID: $invoiceId, User ID: $userId, Country: $clientCountry, Tax Exempt: $isTaxExempt, VAT Number: $vatNumber, Currency: $currency\n";

        // Check if client is in the EU, is tax-exempt, and has a VAT number
        if (in_array($clientCountry, $euCountries) && !empty($isTaxExempt) && !empty($vatNumber)) {
            $note = "0.00% VAT/TAX: 0.00 $currency\nDomestic turnover is not taxable. Your VAT registration number is: $vatNumber - Reverse Charge!";

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
