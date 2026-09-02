package com.farmer.farmer_accounting

import com.farmer.farmer_accounting.R
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import android.util.Log
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONArray

class CropWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        Log.d("KhetiBookWidget", "onUpdate called for ${appWidgetIds.size} widgets")
        val isGujarati = widgetData.getBoolean("isGujarati", false)
        
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_crop_prices).apply {
                val cropDataStr = widgetData.getString("cropData", "[]")
                val crops = JSONArray(cropDataStr)

                // Translate Title
                setTextViewText(R.id.widget_title, if (isGujarati) "ખેતીબુક" else "KhetiBook")
                
                // Reset visibility
                setViewVisibility(R.id.single_crop_container, android.view.View.GONE)
                setViewVisibility(R.id.list_container, android.view.View.GONE)
                setViewVisibility(R.id.empty_text, android.view.View.GONE)
                
                // Reset list rows and dividers
                setViewVisibility(R.id.row_1, android.view.View.GONE)
                setViewVisibility(R.id.div_1, android.view.View.GONE)
                setViewVisibility(R.id.row_2, android.view.View.GONE)
                setViewVisibility(R.id.div_2, android.view.View.GONE)
                setViewVisibility(R.id.row_3, android.view.View.GONE)
                setViewVisibility(R.id.div_3, android.view.View.GONE)
                setViewVisibility(R.id.row_4, android.view.View.GONE)

                try {
                    if (crops.length() == 0) {
                        setViewVisibility(R.id.empty_text, android.view.View.VISIBLE)
                        setTextViewText(R.id.empty_text, if (isGujarati) "કોઈ પાક પિન કરેલ નથી" else "No crops pinned")
                    } else if (crops.length() == 1) {
                        // SINGLE CROP BIG VIEW
                        setViewVisibility(R.id.single_crop_container, android.view.View.VISIBLE)
                        val item = crops.getJSONObject(0)
                        val name = item.getString("name")
                        val min = item.getString("min")
                        val max = item.getString("max")
                        
                        setTextViewText(R.id.single_crop_name, name)
                        setTextViewText(R.id.single_crop_price, "₹$min - $max")
                    } else {
                        // MULTI CROP LIST VIEW
                        setViewVisibility(R.id.list_container, android.view.View.VISIBLE)
                        for (i in 0 until crops.length()) {
                            if (i >= 4) break
                            val item = crops.getJSONObject(i)
                            val name = item.getString("name")
                            val min = item.getString("min")
                            val max = item.getString("max")
                            val displayStr = "₹$min - $max"
                            
                            when (i) {
                                0 -> {
                                    setViewVisibility(R.id.row_1, android.view.View.VISIBLE)
                                    setTextViewText(R.id.crop1_name, name)
                                    setTextViewText(R.id.crop1_price, displayStr)
                                }
                                1 -> {
                                    setViewVisibility(R.id.div_1, android.view.View.VISIBLE)
                                    setViewVisibility(R.id.row_2, android.view.View.VISIBLE)
                                    setTextViewText(R.id.crop2_name, name)
                                    setTextViewText(R.id.crop2_price, displayStr)
                                }
                                2 -> {
                                    setViewVisibility(R.id.div_2, android.view.View.VISIBLE)
                                    setViewVisibility(R.id.row_3, android.view.View.VISIBLE)
                                    setTextViewText(R.id.crop3_name, name)
                                    setTextViewText(R.id.crop3_price, displayStr)
                                }
                                3 -> {
                                    setViewVisibility(R.id.div_3, android.view.View.VISIBLE)
                                    setViewVisibility(R.id.row_4, android.view.View.VISIBLE)
                                    setTextViewText(R.id.crop4_name, name)
                                    setTextViewText(R.id.crop4_price, displayStr)
                                }
                            }
                        }
                    }
                } catch (e: Exception) {
                    Log.e("KhetiBookWidget", "Error parsing crop data", e)
                    setViewVisibility(R.id.empty_text, android.view.View.VISIBLE)
                    setTextViewText(R.id.empty_text, if (isGujarati) "લોડ કરવામાં ભૂલ" else "Error loading crops")
                }
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
