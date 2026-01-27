# App Store Deployment Guide for textcliper

**Created:** January 4, 2026 at 10:30 AM

**Status: ✅ Your app is ready for App Store submission!**

This guide walks you through every step to publish textcliper on the Mac App Store.

---

## Before You Start

**What you need:**
- Apple Developer Program membership ($99/year) - you already have this ✅
- Xcode installed - you have this ✅
- Your app is built and tested - you have this ✅

**Time needed:** About 30-60 minutes for submission, then 24-48 hours for Apple review.

---

## PART 1: FIX THE ICLOUD CONTAINER (Required)

Your app uses iCloud sync, but the container isn't registered yet. Let's fix that.

### Step 1.1: Open Apple Developer Portal

1. Open Safari
2. Go to: https://developer.apple.com
3. Click **"Account"** in the top menu
4. Sign in with your Apple ID

### Step 1.2: Create the iCloud Container

1. In the left sidebar, click **"Certificates, Identifiers & Profiles"**
2. In the left sidebar, click **"Identifiers"**
3. At the top, you'll see a dropdown that says "App IDs" - click it
4. Select **"iCloud Containers"** from the dropdown
5. Click the **blue "+" button** to create a new container
6. Enter these details:
   - **Description:** `textcliper iCloud Container`
   - **Identifier:** `iCloud.L5774582ZK.MIT.textcliper`
7. Click **"Continue"**
8. Click **"Register"**

### Step 1.3: Link Container to Your App ID

1. Go back to **"Identifiers"**
2. Change the dropdown back to **"App IDs"**
3. Find and click on **"MIT.textcliper"**
4. Scroll down to **"iCloud"**
5. Make sure it's checked ✓
6. Click **"Edit"** next to iCloud
7. Check the box next to **"iCloud.L5774582ZK.MIT.textcliper"**
8. Click **"Continue"**
9. Click **"Save"**

### Step 1.4: Update Xcode

1. Open Xcode
2. Open your textcliper project
3. Click on **"textcliper"** in the project navigator (left sidebar)
4. Select the **"textcliper"** target
5. Go to **"Signing & Capabilities"** tab
6. Under **"Signing"**, click the refresh button (circular arrow) or:
   - Uncheck "Automatically manage signing"
   - Check it again
7. Xcode will download the updated provisioning profile

---

## PART 2: CREATE YOUR APP IN APP STORE CONNECT

### Step 2.1: Open App Store Connect

1. Go to: https://appstoreconnect.apple.com
2. Sign in with your Apple ID

### Step 2.2: Create a New App

1. Click **"My Apps"**
2. Click the **blue "+" button** in the top left
3. Select **"New App"**

### Step 2.3: Fill in App Information

Fill in these fields:

| Field | What to Enter |
|-------|---------------|
| **Platforms** | Check **"macOS"** only |
| **Name** | `textcliper` (or your preferred display name) |
| **Primary Language** | English (U.S.) |
| **Bundle ID** | Select **"MIT.textcliper"** from the dropdown |
| **SKU** | `textcliper-001` (any unique identifier) |
| **User Access** | Full Access |

4. Click **"Create"**

---

## PART 3: PREPARE YOUR APP STORE LISTING

You're now on your app's page. Fill in all required information.

### Step 3.1: App Information (Left Sidebar)

Click **"App Information"** in the left sidebar.

**Localizable Information:**
- **Name:** textcliper
- **Subtitle:** Screenshot to Text in Seconds (max 30 characters)

**General Information:**
- **Category:** Utilities
- **Secondary Category:** Productivity (optional)
- **Content Rights:** Select "This app does not contain..."

Click **"Save"** in the top right.

### Step 3.2: Pricing and Availability

Click **"Pricing and Availability"** in the left sidebar.

1. **Price Schedule:** Click "Add Pricing"
   - Select your price (Free, or choose a tier like $0.99, $1.99, etc.)
   - Click "Next" then "Create"

2. **Availability:** All countries should be selected by default

Click **"Save"**

### Step 3.3: App Privacy

Click **"App Privacy"** in the left sidebar.

1. Click **"Get Started"** or **"Edit"**
2. Answer the questions about data collection:
   - If you collect NO user data: Select "No, we do not collect data"
   - If you use iCloud sync: You DO collect data (identifiers)

**For textcliper with iCloud sync, select:**
- **Yes**, we collect data
- Check: **Identifiers** (Device ID for iCloud)
- Mark it as: **Not linked to user**, **Not used for tracking**

3. Click **"Publish"** when done

### Step 3.4: App Version Information

Click on **"1.0 Prepare for Submission"** in the left sidebar (under macOS App).

**Screenshots (REQUIRED)**

You need at least ONE screenshot. Recommended sizes:
- 1280 x 800 pixels
- 1440 x 900 pixels
- 2560 x 1600 pixels
- 2880 x 1800 pixels

**To create screenshots:**
1. Run your app
2. Press `Cmd + Shift + 5`
3. Select the window
4. Save the screenshot
5. Upload it here

**Description (REQUIRED)**

Enter a description of your app. Example:

```
textcliper is your instant screenshot-to-text tool.

Simply press ⌘⇧8 or click the menu bar icon, select any area of your screen, and the text is automatically copied to your clipboard. Perfect for:

• Extracting text from images
• Copying text from non-selectable sources
• Quickly grabbing quotes from videos
• Converting screenshots to editable text

Features:
• One-click OCR text extraction
• Global keyboard shortcut (⌘⇧8)
• Runs quietly in your menu bar
• iCloud sync for capture history
• AI-enhanced OCR option
• Clean, simple, native macOS design
```

**Keywords**

Enter up to 100 characters of keywords (comma-separated):
```
ocr,screenshot,text,extract,copy,clipboard,menu bar,utility,productivity
```

**Support URL (REQUIRED)**

Enter a support URL. Options:
- Your website
- A GitHub repository URL
- A simple support page

Example: `https://github.com/yourusername/textcliper`

**Marketing URL (Optional)**

Same as above, or leave empty.

**Version (REQUIRED)**

Enter: `1.0`

**What's New (Optional for first version)**

Enter: `Initial release`

**Copyright**

Enter: `2024 Your Name` or `2024 MIT`

Click **"Save"** in the top right.

---

## PART 4: BUILD AND UPLOAD YOUR APP

### Step 4.1: Archive Your App in Xcode

1. Open your textcliper project in Xcode
2. In the top bar, make sure you see: **"textcliper > My Mac"**
3. Click **Product** menu → **Archive**
4. Wait for the build to complete (1-3 minutes)
5. The **Organizer** window will open automatically

### Step 4.2: Upload to App Store Connect

1. In the Organizer window, select your new archive
2. Click **"Distribute App"** button on the right
3. Select **"App Store Connect"** → Click **"Next"**
4. Select **"Upload"** → Click **"Next"**
5. Leave all checkboxes at their defaults → Click **"Next"**
6. Select **"Automatically manage signing"** → Click **"Next"**
7. Review the summary → Click **"Upload"**
8. Wait for upload to complete (2-5 minutes)
9. Click **"Done"** when finished

### Step 4.3: Wait for Processing

After upload, Apple processes your build:
- This takes 15-30 minutes
- You'll get an email when it's ready
- The build will appear in App Store Connect

---

## PART 5: SELECT YOUR BUILD AND SUBMIT

### Step 5.1: Add the Build to Your App Version

1. Go back to App Store Connect (https://appstoreconnect.apple.com)
2. Click **"My Apps"** → Click **"textcliper"**
3. Click **"1.0 Prepare for Submission"** in the left sidebar
4. Scroll down to **"Build"** section
5. Click the **"+"** button next to Build
6. Select your uploaded build from the list
7. Click **"Done"**

### Step 5.2: Complete App Review Information

Scroll down to **"App Review Information"**

**Sign-in Information:**
- Check "Sign-in not required" (your app doesn't need login)

**Contact Information:**
- Enter your name, phone, and email

**Notes (Optional):**
Add any notes for the reviewer. Example:
```
This app requires Screen Recording permission to capture screenshots.
After launching, click the menu bar icon (clipboard icon) and select
"Capture Screen to Text" or press ⌘⇧8 to test the OCR functionality.
The app will prompt for Screen Recording permission on first use.
```

### Step 5.3: Final Review

1. Scroll to the top of the page
2. Look for any yellow warning icons - fix those if present
3. Make sure all required fields show green checkmarks

### Step 5.4: Submit for Review

1. Click **"Add for Review"** in the top right corner
2. Review the submission dialog
3. Click **"Submit to App Review"**

---

## PART 6: AFTER SUBMISSION

### What Happens Next

| Timeline | What Happens |
|----------|--------------|
| 0-24 hours | Your app enters "Waiting for Review" status |
| 24-48 hours | Apple reviews your app |
| After approval | Your app goes live on the App Store! |

### If Apple Rejects Your App

Don't panic! Apple will tell you exactly why. Common reasons:

1. **Missing screenshots** - Add the required screenshots
2. **Crashes** - Fix the bug and resubmit
3. **Permission issues** - Check your Info.plist descriptions
4. **Metadata issues** - Fix the text and resubmit

Click "Reply" in App Store Connect to communicate with the reviewer.

### Checking Your App Status

1. Go to App Store Connect
2. Click "My Apps"
3. Your app will show its current status:
   - **Prepare for Submission** - Still editing
   - **Waiting for Review** - In Apple's queue
   - **In Review** - Apple is reviewing now
   - **Pending Developer Release** - Approved, waiting for you
   - **Ready for Sale** - Live on App Store! 🎉

---

## QUICK CHECKLIST

Before submitting, verify:

- [ ] iCloud container registered in Developer Portal
- [ ] Provisioning profiles updated in Xcode
- [ ] App archived with Release configuration
- [ ] Build uploaded to App Store Connect
- [ ] At least 1 screenshot uploaded
- [ ] App description filled in
- [ ] Support URL provided
- [ ] Privacy questions answered
- [ ] Contact info for App Review provided
- [ ] Build selected for this version

---

## TROUBLESHOOTING

### "No suitable application records were found"
- Your Bundle ID in Xcode doesn't match App Store Connect
- Check that MIT.textcliper is selected in both places

### "Missing Compliance"
- After upload, you may need to answer export compliance
- Your app likely doesn't use encryption for export (select "No")

### "Invalid Binary"
- Check your provisioning profiles
- Make sure App Sandbox is enabled
- Verify code signing in Xcode

### Build Not Appearing in App Store Connect
- Wait 15-30 minutes for processing
- Check your email for any error messages from Apple

---

## CONGRATULATIONS! 🎉

Once approved, your app will be live on the Mac App Store!

You can share it with the link:
```
https://apps.apple.com/app/textcliper/id[YOUR_APP_ID]
```

(The App ID will be shown in App Store Connect after your app is live)

---

*Guide created: January 2026*
*App version: 1.0*
