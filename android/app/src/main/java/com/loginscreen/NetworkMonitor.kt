package com.loginscreen

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.callbackFlow

/**
 * Interface for monitoring network connectivity.
 * Provides reactive Flow of online/offline state.
 */
interface NetworkMonitor {
    /**
     * Flow that emits true when device is online, false when offline.
     * Emits current state immediately upon collection.
     */
    val isOnline: Flow<Boolean>
}

/**
 * Android implementation of NetworkMonitor.
 * Uses ConnectivityManager to monitor network state changes.
 */
class NetworkMonitorImpl(private val context: Context) : NetworkMonitor {
    private val connectivityManager =
        context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager

    /**
     * Creates a Flow that emits network connectivity state.
     * Listens to network callbacks and emits state changes reactively.
     */
    override val isOnline: Flow<Boolean> = callbackFlow {
        val callback = object : ConnectivityManager.NetworkCallback() {
            override fun onAvailable(network: Network) {
                trySend(true)
            }

            override fun onLost(network: Network) {
                trySend(false)
            }

            override fun onCapabilitiesChanged(
                network: Network,
                networkCapabilities: NetworkCapabilities
            ) {
                val isConnected = networkCapabilities.hasCapability(
                    NetworkCapabilities.NET_CAPABILITY_INTERNET
                ) && networkCapabilities.hasCapability(
                    NetworkCapabilities.NET_CAPABILITY_VALIDATED
                )
                trySend(isConnected)
            }
        }

        val request = NetworkRequest.Builder()
            .addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
            .build()

        connectivityManager.registerNetworkCallback(request, callback)

        // Check initial state
        val currentNetwork = connectivityManager.activeNetwork
        val capabilities = connectivityManager.getNetworkCapabilities(currentNetwork)
        val isCurrentlyOnline = capabilities?.hasCapability(
            NetworkCapabilities.NET_CAPABILITY_INTERNET
        ) == true && capabilities.hasCapability(
            NetworkCapabilities.NET_CAPABILITY_VALIDATED
        )
        trySend(isCurrentlyOnline)

        awaitClose {
            connectivityManager.unregisterNetworkCallback(callback)
        }
    }
}

