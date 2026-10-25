# Private Android release signing

`android/key.properties` and all `.jks`/`.keystore` files are ignored by Git.
Existing local files remain usable. To configure a new machine, copy
`android/key.properties.example` to `android/key.properties`, fill in its values,
and restore the private keystore from your secure backup. `storeFile` is resolved
relative to `android` (absolute paths also work).

Alternatively, provide these environment variables. They take precedence over
the local properties file:

- `ANDROID_KEYSTORE_PATH`
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`

Release tasks fail when signing configuration is missing; they never fall back
to the debug key. Debug builds do not require release credentials.

## GitHub Actions

Before triggering the release workflow, configure repository Actions secrets:

- `ANDROID_KEYSTORE_BASE64`: base64 of the private keystore file.
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`

For a guided one-time setup on this computer, run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File C:\PROJECTS\visaia\scripts\setup-github-signing.ps1
```

Open [the repository's Actions secrets](https://github.com/kheypaxu/visaia/settings/secrets/actions).
The helper prompts for each exact secret name and copies its existing value to
the clipboard. Paste into GitHub's **Secret** field and choose **Add secret**.
Values are not printed, written to another file, or sent automatically. The last
copied value is cleared from the clipboard after the guided setup finishes.
Use `-SecretName ANDROID_KEYSTORE_BASE64` (or another name above) to copy just one
value, or `-Check` to verify the local values without copying anything.

After GitHub lists all four secrets, commit and push the signing/workflow changes
on the branch used for the release. Create the next version tag from that updated
commit, or run the updated workflow manually. Rerunning an older tag continues to
use its older workflow and source. This setup does not require a local APK build.
See [GitHub's repository secret instructions](https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/use-secrets).

The workflow restores the keystore into the runner's temporary directory,
passes passwords through the build environment, and removes the temporary file
after building. Credentials are not written into tracked files or APK artifacts.

## Previously committed credentials

The old keystore and password configuration existed in earlier commits. Removing
them from the index prevents future commits from including them but does not
revoke copies or remove Git history. Treat that material as exposed.

Confirm how VISAIA is distributed before replacing its signing identity. With
Play App Signing, follow the Play Console upload-key reset process when this is
an upload key. If it is the app signing key, use the supported signing-key upgrade
process. For APKs distributed directly, changing the signing key can prevent
installed apps from accepting an update; plan migration before replacement.
Changing a keystore password does not revoke an already copied private key.
See the official [Android app signing and key management guidance](https://developer.android.com/studio/publish/app-signing).

History rewriting and remote force-pushes require coordination with repository
collaborators. They are separate from this working-tree cleanup and do not revoke
already downloaded copies. No signing key was replaced and no history was
rewritten by this change.
