# Subscriptiono

[![CircleCI](https://circleci.com/gh/sstgithub/subscriptiono.svg?style=svg&circle-token=485d7e33c3edbd94342ce58c7a8087c0e09b12b3)](https://circleci.com/gh/sstgithub/subscriptiono)

Website: https://www.subscriptiono.herokuapp.com

## Overview

Somewhat similar to Unroll.me, Subscriptiono will help the user organize their inbox and not get distracted by all those informational and offer emails they get from newsletters to which they are subscribed. Unlike Unroll.me, Subscriptiono only looks for subscription emails and only for the purposes of displaying them to the user (More information [here](https://www.nytimes.com/2017/04/24/technology/personal-data-firm-slice-unroll-me-backlash-uber.html) and a response from the company as well as thoughts of users [here](http://blog.unroll.me/we-can-do-better/)).

Once the user logs in, an IMAP sync job kicks off (requeues every 24 hours). This job:

1. Searches their email for new subscription emails based on UID numbers for each message in each folder, per the [Internet Message Access Protocol (IMAP)](https://tools.ietf.org/html/rfc3501#section-2.3.1.1)
2. Categorizes the message as either an offer or as information. If it's an offer, it also attempts to extract a relevant datetime about when this offer may end.
3. Stores these messages with the sender email, body html, category, extracted datetime (if there was one), and time it was received

The user dashboard shows only the last received message for each sender email and category (since there are only two categories for now ("Offer" and "Informational"), each sender will one message for their "Offer" email and/or one message for their "Informational" email)

## Technical Overview

I used:
- standard IMAP search for finding emails with the word "Unsubscribe" in it (using Ruby's Net::IMAP library)
- devise with Google OAuth login which would also ask for email permissions so the IMAP sync job could kick off as soon as user registered
- the following rules extracted from the IMAP whitepaper to generate how my IMAP sync job would work:
  1. UID number is required to be unique per folder & the same UID number may never be used again in a folder (even if the message is deleted)
  2. UID number will increment by 1 for each new message
  3. Folder names must be unique
  4. Folder "UIDVALIDITY" values must be unique. UIDVALIDITY is a unique identifier for folders that allows an IMAP client to determine if it is still syncing with the same folder as last time or if that folder has been deleted and replaced with another folder with the same name.

  - So the imap sync job here: categorizes and saves each message it finds, stores the last highest UID number found in messages for each folder, and next time finds the same folder based on name and UID validity (or creates a new one) and starts the process again for messages with UID number more than the last highest UID number so only new messages since the last sync are found, categorized, and saved.




## Installation

- Ruby 2.4.1
- Rails 5.1.0

## Usage

- You can find the working app at: www.subscriptiono.herokuapp.com
  - Login with your Google OAuth and the IMAP sync process will automatically begin. In a few hours you will see the latest received emails for all your subscriptions.


## TODO

- Allow user to signup with any email service and autoconfig IMAP sync (using login authentication)
- Transfer messages to a "Subscriptiono" folder in user email once stored on Subscriptiono, so subscription messages don't distract user when they are viewing their inbox
- Find prices in offer messages
	- Generate a historical chart of prices offered for each product for each sender
- Privacy and Security
	- Give user option to delete all their messages at once
	- Either don't store body of message (store link to message on user account if user wishes to see whole message) or encrypt in database
