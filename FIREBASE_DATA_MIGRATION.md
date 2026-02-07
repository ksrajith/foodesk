# Move Firestore Data to Your New Firebase Project

This guide copies your **Firestore collections** from the **old** Firebase project to your **new (personal)** project. Your app uses these collections:

- **users**
- **registration_requests**
- **products**
- **orders**

Use either **Option A** (Google Cloud Console) or **Option B** (gcloud CLI).

---

## Prerequisites

1. **Blaze plan (billing)** on **both** the old and new Firebase projects.  
   [Firebase pricing](https://firebase.google.com/pricing) → upgrade to Blaze if needed.

2. **Cloud Storage bucket**  
   Create one bucket to hold the export. It can be in the **old** project, the **new** project, or a separate project. You’ll use it in the steps below.

3. **Permissions**  
   Your Google account (or the account running the commands) needs:
   - In the **old** project: permission to export Firestore and write to the bucket (e.g. Owner or Cloud Datastore Import Export Admin).
   - In the **new** project: permission to import Firestore and read from the bucket.

---

## Option A: Using Google Cloud Console (no CLI)

### 1. Export from the OLD project

1. Open [Google Cloud Console](https://console.cloud.google.com) and **select the OLD Firebase project** (top project selector).
2. Go to **Firestore** → **Databases** (or [Databases](https://console.cloud.google.com/datastore/databases)).
3. Select your database (usually **“(default)”**).
4. In the left menu, open **Import/Export**.
5. Click **Export**.
6. Choose:
   - **Export entire database**, or  
   - **Export one or more collection groups** and select: `users`, `registration_requests`, `products`, `orders`.
7. Under **Choose Destination**, pick or enter your **Cloud Storage bucket** (e.g. `gs://your-bucket-name/firestore-export/`).  
   - Prefer a path like `gs://BUCKET/firestore-export/` so the export goes into a clear folder.
8. Click **Export** and wait until the job finishes (you can check status on the same Import/Export page).

### 2. Allow the NEW project to read the bucket (if bucket is in OLD project)

If the bucket lives in the **old** project, the **new** project’s Firestore service agent must be able to read it:

1. In Cloud Console, go to **Cloud Storage** → **Buckets** and open the bucket you used.
2. Open the **Permissions** tab → **Grant access**.
3. **New principals:**  
   `service-NEW_PROJECT_NUMBER@gcp-sa-firestore.iam.gserviceaccount.com`  
   (Replace `NEW_PROJECT_NUMBER` with the **new** project’s number: Firebase Console → Project settings → General → Project number.)
4. **Role:** **Storage Object Viewer** (or **Storage Admin** if you prefer).
5. Save.

If the bucket is in the **new** project, you can skip this (same-project access is already allowed).

### 3. Import into the NEW project

1. In Google Cloud Console, **switch to the NEW Firebase project**.
2. Go to **Firestore** → **Databases** → select **(default)** (or the database you use).
3. Open **Import/Export**.
4. Click **Import**.
5. In **Filename**, enter the path to the **export metadata** file. The export creates a folder in the bucket; the file is named like:
   - `gs://BUCKET/firestore-export/2026-02-06T12-00-00_12345/2026-02-06T12-00-00_12345.overall_export_metadata`
   Use **Browse** to select that `.overall_export_metadata` file inside the export folder.
6. Click **Import** and wait until it completes.

After the import finishes, your new project’s Firestore will contain the same data (same collection and document IDs). Deploy your Firestore rules to the new project if you haven’t already (`firebase use <new-project>`, then `firebase deploy --only firestore:rules`).

---

## Option B: Using gcloud CLI

Replace placeholders:

- `OLD_PROJECT_ID` = old Firebase project ID  
- `NEW_PROJECT_ID` = new (personal) Firebase project ID  
- `BUCKET_NAME` = your Cloud Storage bucket name  
- `EXPORT_PREFIX` = folder path inside the bucket (e.g. `firestore-export`)

### 1. Create a bucket (if needed)

```bash
# Use either the old or new project
gcloud config set project OLD_PROJECT_ID
gcloud storage buckets create gs://BUCKET_NAME --location=us-central1
```

(Pick a `location` near your Firestore region.)

### 2. Export from the OLD project

```bash
gcloud config set project OLD_PROJECT_ID
gcloud firestore export gs://BUCKET_NAME/EXPORT_PREFIX --database='(default)'
```

To export only your app’s collections:

```bash
gcloud firestore export gs://BUCKET_NAME/EXPORT_PREFIX \
  --collection-ids=users,registration_requests,products,orders \
  --database='(default)'
```

The command prints an export path like `gs://BUCKET_NAME/EXPORT_PREFIX/2026-02-06T12-00-00_12345`. Note that folder name; you need it for import.

### 3. Grant the NEW project read access to the bucket (if bucket is in OLD project)

Get the **new** project number (Firebase Console → Project settings). Then:

```bash
gsutil iam ch serviceAccount:service-NEW_PROJECT_NUMBER@gcp-sa-firestore.iam.gserviceaccount.com:objectViewer gs://BUCKET_NAME
```

If the bucket is in the **new** project, skip this.

### 4. Import into the NEW project

Use the **exact** export folder path from step 2 (including the timestamped subfolder):

```bash
gcloud config set project NEW_PROJECT_ID
gcloud firestore import gs://BUCKET_NAME/EXPORT_PREFIX/TIMESTAMPED_FOLDER_NAME/ --database='(default)'
```

Example:

```bash
gcloud firestore import gs://my-bucket/firestore-export/2026-02-06T12-00-00_12345/ --database='(default)'
```

If you exported only specific collections, the import will only bring in those collections.

---

## After migration

1. **Rules**  
   Deploy rules to the new project:
   ```bash
   firebase use NEW_PROJECT_ID
   firebase deploy --only firestore:rules
   ```

2. **App**  
   Your app is already pointed at the new project via the new `google-services.json` (and iOS config). No code changes needed.

3. **Auth users**  
   Export/import **does not** copy Firebase Authentication users. If you need the same users in the new project:
   - Use [Auth export/import](https://firebase.google.com/docs/auth/admin/manage-users#bulk_user_import) (requires Admin SDK / service account), or  
   - Have users sign up again in the new project.

4. **Clean up**  
   You can delete the export files from the bucket after confirming the new project’s data is correct.

---

## Summary

| Step | Action |
|------|--------|
| 1 | Export Firestore from **old** project to a Cloud Storage bucket (Console or gcloud). |
| 2 | If the bucket is in the old project, grant the **new** project’s Firestore service agent read access to the bucket. |
| 3 | Import from that bucket into the **new** project (Console or gcloud). |
| 4 | Deploy Firestore rules to the new project and optionally re-seed or re-create Auth users. |

Your Firestore **tables** (users, registration_requests, products, orders) will then be in the new project; Auth must be handled separately if you need the same users.
