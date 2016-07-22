---
layout: post
title: "Authenticate with Vault from Chrome"
date: "2016-07-22 15:56:08 +0200"
author: jovandeginste
comments: true
tags:
  - vault
published: true
---

Now that we can [use client certificates to authenticate with Vault]({% post_url 2016-07-20-use-vault-with-client-certificates %}), we can use that certificate in our browser (Chrome) in combination with [Postman](http://www.getpostman.com/).

## Step 1 - get the certificate in the browser

The easiest way is to convert the key and certificate into a `p12` container file. Openssl supports this out of the box:

```
$ openssl pkcs12 -export -clcerts -in cert.pem -inkey key.pem -out vaultcert.p12
Enter pass phrase for key.pem:
Enter Export Password:
Verifying - Enter Export Password:
```

I obviously used the same password to encrypt the p12 container ;-) Now get the `vaultcert.p12` file to the machine with your browser (if it's not the same) and import it. [Here](https://support.globalsign.com/customer/portal/articles/1215006-install-pkcs-12-file---linux-ubuntu-using-chrome) and [here](https://www.comodo.com/support/products/authentication_certs/setup/win_chrome.php#import) are tutorials describing the steps, so I wont repeat.

When you browse to your Vault setup, you should get a prompt for a client certificate, and your freshly imported Vault certificate should now be listed.

## Step 2 - install Postman

I won't go into too much detail - [Postman](http://www.getpostman.com/) gives you a flexible REST client. There are many other options here. Installation is so straight forward, I will leave it as an exercise to the reader...

## Step 3 - communicate with Vault

First, we use the certificate to get a temporary token.

In the builder, set the request type to `POST` and the url to your Vault server's certificat authentication API: `https://vault.example.com/v1/auth/cert/login`. When you click "send", you should get a popup asking you to select a certificate similar to [this one](https://developer.chrome.com/static/images/certificate_provider_selection_dialog.png). Select the correct certificate from the list. You should now get a `Body` containing (among other) a valid Vault token (`client_token`):

```json
{
    "lease_id": "",
    "renewable": false,
    "lease_duration": 0,
    "data": null,
    "wrap_info": null,
    "warnings": null,
    "auth": {
        "client_token": "40xxxxd8-xxxx-bfaf-xxxx-480bxxxx8615",
        "accessor": "0fxxxxea-xxxx-0253-xxxx-52fdxxxx36cf",
        "policies": [
            "root"
        ],
        "metadata": {
            "authority_key_id": "",
            "cert_name": "your.name",
            "common_name": "Your Name",
            "subject_key_id": ""
        },
        "lease_duration": 3600,
        "renewable": true
    }
}
```

Now we can use the token to do other things.

Look up the metadata of the Vault token:

* switch the `POST` back to `GET`
* enter this url: `https://vault.example.com/v1/auth/token/lookup-self`
* add the Vault token in Headers (key name `X-Vault-Token`)

The result should tell you whether your token is sill valid (`ttl`) and what policies are attached to it.
