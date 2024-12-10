<?php
/**
 * Private Devops LTD - WHMCS VAT Reverse Charge Hook
 * --------------------------------------------
 * This hook automatically applies reverse charge notes to invoices
 * for eligible EU clients based on VAT regulations.
 *
 * Author: Private Devops LTD
 * Website: https://privatedevops.com
 * Description: Updates invoice notes for clients who are VAT exempt
 * and within the EU, per regulatory requirements.
 *
 * How to Use:
 * -----------
 * 1. Place this script in the "includes/hooks/" directory of your WHMCS installation.
 * 2. Ensure the correct VAT custom field ID is set in the script (default: 10).
 *    - Check the VAT custom field ID in your WHMCS database under `tblcustomfields`.
 *    - Update the line: `->where('fieldid', 10)` with your custom field ID if necessary.
 * 3. The script automatically triggers whenever an invoice is created in WHMCS.
 * 4. Debugging:
 *    - Use the WHMCS Activity Log (Utilities > Logs > Activity Log) to track execution.
 *    - Logs start with "Private Devops VAT Hook" for easy identification.
 * 5. Requirements:
 *    - Clients must have a VAT number stored in the correct custom field.
 *    - Clients must have their tax exemption status enabled.
 *    - Client country must belong to the EU.
 *
 * Notes:
 * ------
 * - If conditions are not met (e.g., missing VAT number, non-EU country),
 *   the script skips adding the reverse charge note to the invoice.
 * - Ensure that VAT numbers are properly formatted in your WHMCS database.
 * - This hook applies to new invoices only; old invoices can be updated
 *   using a separate one-time script.
 */

use WHMCS\Database\Capsule;

add_hook('InvoiceCreation', 1, function ($vars) {
    $invoiceId = $vars['invoiceid'];

    // Fetch invoice details to get the user ID
    $invoice = Capsule::table('tblinvoices')
        ->where('id', $invoiceId)
        ->first(['userid']);

    if (!$invoice) {
        logActivity("VAT Hook Debug: No invoice found for Invoice ID: $invoiceId");
        return;
    }

    $userId = $invoice->userid;

    // Debug: Log User ID
    logActivity("VAT Hook Debug: Retrieved User ID: $userId for Invoice ID: $invoiceId");

    // Retrieve VAT number from custom field
    try {
        $vatNumber = Capsule::table('tblcustomfieldsvalues')
            ->where('fieldid', 10) // Ensure this is the correct custom field ID
            ->where('relid', $userId)
            ->value('value');

        // Log VAT Number Debugging Info
        if ($vatNumber) {
            logActivity("VAT Hook Debug: Retrieved VAT Number: $vatNumber for User ID: $userId");
        } else {
            logActivity("VAT Hook Debug: No VAT Number found for User ID: $userId in fieldid 10");
        }
    } catch (\Exception $e) {
        logActivity("VAT Hook Debug: Error retrieving VAT Number: " . $e->getMessage());
        return;
    }

    // Fetch client details
    $clientDetails = Capsule::table('tblclients')
        ->where('id', $userId)
        ->first(['country', 'taxexempt']);

    if (!$clientDetails) {
        logActivity("VAT Hook Debug: No client found for User ID: $userId");
        return;
    }

    $clientCountry = $clientDetails->country;
    $isTaxExempt = $clientDetails->taxexempt; // '1' or 'on' means tax-exempt

    // Fetch the client currency ID
    $currencyId = Capsule::table('tblclients')
        ->where('id', $userId)
        ->value('currency');

    logActivity("VAT Hook Debug: Retrieved Currency ID: $currencyId for User ID: $userId");

    // Fetch the currency code
    $currency = Capsule::table('tblcurrencies')
        ->where('id', $currencyId)
        ->value('code');

    if ($currency) {
        logActivity("VAT Hook Debug: Retrieved Currency Code: $currency for User ID: $userId");
    } else {
        logActivity("VAT Hook Debug: Failed to retrieve Currency Code for Currency ID: $currencyId");
    }

    // Log all variables for debugging
    logActivity("VAT Hook Debug: Invoice ID: $invoiceId, User ID: $userId, Country: $clientCountry, Tax Exempt: $isTaxExempt, VAT Number: $vatNumber");

    // Check if client is in the EU, is tax-exempt, and has a VAT number
    if (in_array($clientCountry, ['AT', 'BE', 'CY', 'CZ', 'DE', 'DK', 'EE', 'ES', 'FI', 'FR', 'GR', 'HR', 'HU', 'IE', 'IT', 'LT', 'LU', 'LV', 'MT', 'NL', 'PL', 'PT', 'RO', 'SE', 'SI', 'SK']) && !empty($isTaxExempt) && !empty($vatNumber)) {
	    // $note = "*Reverse charge applies to this purchase - VAT Number: $vatNumber. VAT at 0% has been applied.";
        $note = "0.00% VAT/TAX: 0.00 $currency\nDomestic turnover is not taxable. Your VAT registration number is: $vatNumber - Reverse Charge!";
        Capsule::table('tblinvoices')
            ->where('id', $invoiceId)
            ->update(['notes' => $note]);

        logActivity("VAT Hook Debug: Added reverse charge note to Invoice ID: $invoiceId for User ID: $userId");
    } else {
        logActivity("VAT Hook Debug: Conditions not met for Invoice ID: $invoiceId. Country: $clientCountry, Tax Exempt: $isTaxExempt, VAT: $vatNumber");
    }
});
