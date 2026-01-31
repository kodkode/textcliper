# CloudKit Schema Fix - Enable Download Functionality

## Current Status

✅ **Upload to iCloud**: WORKING
❌ **Download from iCloud**: DISABLED (temporarily)

Your app successfully uploads all captures to iCloud, but downloading from other devices is currently disabled due to a missing CloudKit schema index.

## The Problem

The CloudKit database is missing an index for the `timestamp` field, which causes query errors:
```
❌ Failed to download items: Field 'recordName' is not marked queryable
```

## The Solution

Add the `timestamp` field as an indexed field in your CloudKit schema.

---

## Step-by-Step Fix

### 1. Open CloudKit Dashboard

1. Go to [https://icloud.developer.apple.com/dashboard](https://icloud.developer.apple.com/dashboard)
2. Sign in with your Apple Developer account
3. Select your container: **iCloud.L5774582ZK.MIT.textclipper**
4. Make sure you're in the **Development** environment (blue "D" icon at top)

### 2. Navigate to Schema → Indexes

1. Click **Schema** in the left sidebar
2. Click **Indexes**
3. Find **CaptureHistory** record type (should already be selected)

### 3. Add `timestamp` Index

Click the **"+" button** in the top right of the Indexes section

**Configure the new index:**
- **Field Name**: `timestamp`
- **Index Type**:
  - ✅ Check **"Queryable"**
  - ✅ Check **"Sortable"**
  - ⬜ "Searchable" is optional (not needed for timestamp)

Click **Save**

### 4. Optional: Add `text` Index

While you're at it, you might want to add a `text` field index for searching:

Click **"+" button** again

**Configure:**
- **Field Name**: `text`
- **Index Type**:
  - ✅ Check **"Queryable"**
  - ✅ Check **"Searchable"** (for text search)
  - ⬜ "Sortable" is optional

Click **Save**

### 5. Deploy Schema Changes

1. At the bottom left, click **"Deploy Schema Changes..."**
2. Review the changes
3. Click **Deploy** to Development environment

**Note**: Schema changes take a few minutes to propagate.

### 6. Re-enable Download in Code

Once the schema is deployed, you can re-enable the download functionality:

**Option A**: I can update the code for you
**Option B**: Manually update `CloudSyncService.swift`:

Find the `downloadNewItems()` function and replace the temporary stub with a proper query implementation.

---

## Verification

After deploying the schema changes, your CloudKit indexes should look like this:

```
CaptureHistory
├─ characterCount (queryable, sortable)
├─ deviceName (queryable, searchable, sortable)
├─ id (queryable, searchable, sortable)
├─ text (queryable, searchable) ← NEW (optional)
├─ timestamp (queryable, sortable) ← NEW (required)
└─ wordCount (queryable, sortable)
```

---

## Testing After Fix

1. **Deploy the schema** in CloudKit Dashboard
2. **Wait 2-3 minutes** for changes to propagate
3. **Let me know** and I'll re-enable the download code
4. **Run the app** and capture something
5. **Check the console** - you should see:
   ```
   ✅ Uploaded item to iCloud: ...
   📥 Downloaded new item from iCloud: ...
   ✅ Sync completed: 1 uploaded, 0 downloaded
   ```

---

## Why This Is Needed

CloudKit requires **explicit indexing** for any field you want to:
- **Query** (filter results)
- **Sort** (order results)
- **Search** (text search)

Without these indexes, CloudKit throws "field not marked queryable" errors.

The `timestamp` field is used to:
- Sort captures by recency
- Filter for recent items
- Enable proper sync ordering

---

## Current Workaround

Until you fix the schema, the app:
- ✅ **Uploads** all your captures to iCloud (working!)
- ✅ **Saves** locally with encryption (working!)
- ⏸️ **Skips** download from other devices (temporarily disabled)

Your data is **safe and backed up** - you just can't sync FROM other devices yet.

---

## Need Help?

If you have trouble with the CloudKit Dashboard, let me know and I can:
1. Provide more detailed screenshots
2. Help troubleshoot deployment issues
3. Explain any errors you encounter

---

**Last Updated**: October 26, 2025
**Status**: Waiting for CloudKit schema deployment
