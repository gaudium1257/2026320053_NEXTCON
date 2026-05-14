package com.example.next_contest

import android.os.Bundle
import androidx.core.view.WindowCompat
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Disable edge-to-edge: system navigation bar uses its own space,
        // app layout stops above it.
        WindowCompat.setDecorFitsSystemWindows(window, true)
    }
}
