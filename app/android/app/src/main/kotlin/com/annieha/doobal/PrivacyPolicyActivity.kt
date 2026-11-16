package com.annieha.doobal

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.os.Bundle

// Health Connect 권한 화면의 '개인정보 처리방침' 링크(ACTION_SHOW_PERMISSIONS_RATIONALE, 안드로이드 14 이상은
// VIEW_PERMISSION_USAGE)가 여는 화면: 처리방침 웹 페이지를 브라우저로 열고 바로 닫는다.
// 주소는 res/values/strings.xml privacy_policy_url (앱 쪽 lib/app/links.dart와 같은 값)
class PrivacyPolicyActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        try {
            startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(getString(R.string.privacy_policy_url))))
        } catch (e: ActivityNotFoundException) {
            // 브라우저가 없으면 그냥 닫는다
        }
        finish()
    }
}
