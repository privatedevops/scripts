# Magento 2 Custom Invoice PDF Override Module

This Magento 2 module overrides the default invoice PDF generation to include additional fields such as **Invoice Date**, **Order Date**, and ensures that translations are properly applied per store locale (e.g., DE for Germany). This is particularly useful for multilingual stores operating across the EU or globally.

---

## ✅ Features

- Adds **Invoice Date** and **Order Date** to the top right of the invoice
- Supports multi-language PDF generation based on the **store where the order was placed**
- Uses **CSV-based i18n translation**
- Complies with **EU invoicing requirements**
- Minimal override for maintainability

---

## 📂 Installation

1. Place the module in your Magento installation under:

```
app/code/Vendor/PdfOverride
```

2. Run Magento setup commands:

```bash
bin/magento module:enable Vendor_PdfOverride
bin/magento setup:upgrade
bin/magento setup:di:compile
bin/magento cache:flush
```

3. Make sure your folder structure includes:

```
app/code/Vendor/PdfOverride/
├── etc/
│   ├── di.xml
│   └── module.xml
├── i18n/
│   └── de_DE.csv
├── Model/
│   └── Order/
│       └── Pdf/
│           └── Invoice.php
└── registration.php
```

---

## 🌍 Translations (i18n)

For multilingual PDF generation, create CSV files like `i18n/de_DE.csv`.

**Example `de_DE.csv`:**

```csv
"Order # ","Bestellnummer:"
"Invoice Date: ","Rechnungsdatum:"
"Order Date: ","Bestelldatum:"
"Sold to:","Rechnung an:"
"Ship to:","Lieferung an:"
"Payment Method:","Zahlungsmethode:"
"Shipping Method:","Versandart:"
"Total Shipping Charges","Versandkosten insgesamt"
"Title","Bezeichnung"
"Number","Nummer"
"Invoice # ","Rechnung Nr. "
```

> You can generate phrases automatically using:
> ```bash
> bin/magento i18n:collect-phrases -o app/code/Vendor/PdfOverride/i18n/de_DE.csv app/code/Vendor/PdfOverride
> ```

---

## 📅 Why Add Invoice Date?

Including the **invoice date** is **legally required** in many jurisdictions, especially within the **European Union**. According to [EU VAT Directive 2006/112/EC](https://eur-lex.europa.eu/legal-content/EN/TXT/?uri=CELEX:32006L0112), Article 226:

> Every VAT invoice must include:
> - A sequential invoice number
> - The **invoice date**
> - The date of the taxable supply (if different)

Failing to include the invoice creation date may result in:
- Incompliance with tax authority audits
- Rejection of invoices by B2B clients
- Accounting errors or fines

---

## 📌 Additional Notes

- The module uses `\Magento\Store\Model\App\Emulation` to **dynamically switch locale** when generating invoices per store.
- Admin user interface language does **not** affect PDF language anymore.
- To test translations, ensure orders are created on the desired language store view.

---

## 🧩 Compatibility

- Magento 2.4.4+
- Tested on Magento 2.4.7–2.4.8
- Compatible with multi-store, multi-language setups

---

## 📞 Need Help?

For Magento PDF customization or multilingual store setup, contact [Private DevOps LTD](https://privatedevops.com) for commercial support.

---

## 🪪 License

MIT License

Copyright (c) 2025

Permission is hereby granted, free of charge, to any person obtaining a copy  
of this software and associated documentation files (the "Software"), to deal  
in the Software without restriction, including without limitation the rights  
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell  
copies of the Software, and to permit persons to whom the Software is  
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all  
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR  
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,  
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE  
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER  
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,  
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE  
SOFTWARE.
