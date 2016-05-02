---
layout: post
title: "Get beID up and running on Ubuntu+Firefox"
date: "2009-06-18 09:29:46 +0200"
comments: true
tags:
- beid
---

*Warning - this is from my archive*

Getting your beID (Belgian Identity smart card) working for usage on taxonweb and other e-gov facilities is pretty easy. There's a lot of information on [http://eid.belgium.be/](http://eid.belgium.be/) for other OS'es/browsers if you need it; here are the steps for Ubuntu and Firefox:

1 install the necessary packages (from the official repo's)
  ```bash
	sudo apt-get install beidgui libbeid2-dev libbeid2 libbeidlibopensc2-dev libbeidlibopensc2 beid-tools pcscd libpcsclite-dev
	```

  This is more than strictly necessary, but I did not check which packages are NOT needed - too much work ;-)

2 try your eID card
  Starting the beidgui (from commandline): this starts a nice gui with empty fields. Insert your eID card in you card reader and click the "read" button (top left). Your details should show now.

3 type the following url in your browser: `file:///usr/share/beid/beid-pkcs11-register.html`

	This should ask you for confirmation to add the module, then tell you the module was added. If not, good luck finding the problem ;-) One thing might be to restart the beid and pcscd services.

4 go to taxonweb and try the eID login method
  First, insert your eID card (and give it a few seconds to detect). Then click the "logon" button. It should prompt you for a certificate for authentication, and "BELPIC" should be available.

  If you click ok, the system will ask you for your pin, and then you'll be authenticated.

If it does not ask you for a certificate, it probably shows you the following:

```
Beveiligde verbinding mislukt

Fout tijdens het verbinden met ccff02.minfin.fgov.be.

SSL-peer kon niet onderhandelen over een acceptabele set beveiligingsparameters.

(Foutcode: ssl_error_handshake_failure_alert)

De pagina die u wilt bekijken kan niet worden weergegeven omdat de echtheid van de ontvangen gegevens niet kon worden geverifieerd.

  Neem contact op met de website-eigenaars om ze te informeren over dit probleem.
```

The problem might be a failure to detect your eID (did you try beidgui?), or the browser module not loaded correctly.. Retry?
