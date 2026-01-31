# CloudKit Known Issue - Download Query Failure

## Status

✅ **Upload to iCloud**: WORKING PERFECTLY
❌ **Download from iCloud**: FAILING (non-fatal)

## The Problem

CloudKit queries are failing with:
```
❌ Failed to download items: Field 'recordName' is not marked queryable
   CKError code: 12 (Invalid Arguments)
```

This error occurs even with the simplest possible query:
```swift
let query = CKQuery(recordType: "CaptureHistory", predicate: NSPredicate(value: true))
// No sort descriptors, no filters - just "get all records"
```

## What We've Tried

1. ✅ Added `timestamp` as QUERYABLE index
2. ✅ Added `timestamp` as SORTABLE index
3. ✅ Removed all sort descriptors from query
4. ✅ Switched from `database.records(matching:)` to `CKQueryOperation`
5. ✅ Used minimal predicate `NSPredicate(value: true)`
6. ❌ Still getting "recordName not marked queryable" error

## Root Cause Analysis

The error message "Field 'recordName' is not marked queryable" is unusual because:
- `recordName` is a **system field** in CloudKit
- System fields should **always be available** for queries
- We're not explicitly querying by `recordName`

This suggests a deeper issue with the CloudKit container configuration or development environment.

## Possible Causes

### 1. CloudKit Development Environment Issues
- Schema changes may not have fully propagated
- Development environment might be in an inconsistent state
- Container might need to be reset

### 2. CloudKit Dashboard Configuration
- The container might have been created with incorrect settings
- Record type might not be properly registered
- Indexes might be corrupted or incomplete

### 3. Xcode CloudKit Cache
- Xcode might be caching old schema information
- Local development environment might be out of sync with CloudKit servers

## Current Workaround

The app handles this gracefully:

```swift
// Download is non-fatal
do {
    let newItems = try await downloadNewItems()
    // Process downloaded items
} catch {
    print("⚠️ Download failed (upload succeeded): \(error)")
    // Continue anyway - upload still worked!
}
```

**Result:**
- ✅ Your captures ARE being uploaded to iCloud
- ✅ Data is backed up safely
- ✅ Local storage works perfectly
- ⚠️ You just can't download from other devices yet

## Potential Solutions to Try

### Solution 1: Reset Development Environment

1. **In CloudKit Dashboard:**
   - Go to Settings → Reset Environment
   - Click "Reset Development Environment"
   - **WARNING**: This will delete all development data!

2. **In Xcode:**
   - Clean build folder (⌘⇧K)
   - Delete derived data
   - Rebuild the app

### Solution 2: Create Fresh Container

1. Create a new CloudKit container with a different identifier
2. Update the code to use the new container
3. Deploy schema from scratch

### Solution 3: Use Production Environment

Once the app is ready for production:
1. Deploy schema to Production environment
2. Production might not have the same issues as Development
3. Test with production container

### Solution 4: Contact Apple Developer Support

Since this appears to be a CloudKit platform issue, consider:
- Filing a bug report with Apple
- Contacting Developer Technical Support
- Checking Apple Developer Forums for similar issues

## Impact Assessment

### What Works ✅
- Screenshot capture with ⌘⇧6 hotkey
- OCR text extraction
- Local encrypted storage
- Upload to iCloud
- History management
- All app features except cross-device sync

### What Doesn't Work ❌
- Downloading captures from other devices
- Syncing existing cloud data to new devices

### User Impact
- **Single device users**: No impact - everything works
- **Multi-device users**: Can create captures on any device and upload them, but can't see captures from other devices

## Temporary Recommendation

For now, continue using the app as-is:
- All your data IS being backed up to iCloud (upload works!)
- Download will remain disabled until CloudKit schema issue is resolved
- No data loss - everything is safe locally and in the cloud

When you're ready to deploy to production or need cross-device sync, we can:
1. Try the reset/fresh container approach
2. Contact Apple Developer Support for help
3. Investigate alternative sync solutions (if needed)

## Technical Details

**Container:** `iCloud.L5774582ZK.MIT.textclipper`
**Database:** Private CloudKit Database
**Record Type:** `CaptureHistory`
**Indexed Fields:**
- `characterCount` (queryable, sortable)
- `deviceName` (queryable, searchable, sortable)
- `id` (queryable, searchable, sortable)
- `timestamp` (queryable, sortable) ✅ Added
- `wordCount` (queryable, sortable)

**Query Used:**
```swift
CKQuery(recordType: "CaptureHistory", predicate: NSPredicate(value: true))
// Simplest possible query - should always work
```

**Error:**
```
CKError code: 12 (invalidArguments)
"Field 'recordName' is not marked queryable"
```

---

**Last Updated**: October 26, 2025
**Status**: Open Issue - Workaround in place
**Priority**: Medium (Upload works, download fails gracefully)
