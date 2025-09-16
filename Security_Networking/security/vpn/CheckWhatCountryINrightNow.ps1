# Fastest: returns just the 2-letter ISO code
(Invoke-RestMethod -Uri 'https://ipinfo.io/country').Trim()

# More detail: returns the full JSON if you want city/ASN too
$geo = Invoke-RestMethod -Uri 'https://ipinfo.io/json'
$geo.country        # country code (e.g. "NL")
$geo.country_name   # full name if the API provides it

