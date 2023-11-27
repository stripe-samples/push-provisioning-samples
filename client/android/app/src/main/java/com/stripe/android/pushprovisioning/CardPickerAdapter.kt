package com.stripe.android.pushprovisioning

import android.content.Context
import android.view.LayoutInflater
import android.view.ViewGroup
import android.widget.LinearLayout
import androidx.recyclerview.widget.RecyclerView
import com.stripe.android.pushprovisioning.databinding.CardPickerItemBinding
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

class CardPickerAdapter(
    private val context: Context,
    private val cards: List<CardTokenizationStatus>,
    private val onCardClick: (CardTokenizationStatus) -> Unit,
) : RecyclerView.Adapter<CardViewHolder>() {

    private val prettyJson: Json by lazy {
        Json {
            prettyPrint = true
        }
    }

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): CardViewHolder {
        return CardViewHolder(CardPickerItemBinding.inflate(LayoutInflater.from(context)).root)
    }

    override fun onBindViewHolder(holder: CardViewHolder, position: Int) {
        val cardTokenizationStatus = cards[position]
        val itemView = CardPickerItemBinding.bind(holder.itemView)
        itemView.cardItem.text = prettyJson.encodeToString(cardTokenizationStatus.card)
        itemView.addToGooglePayButton.root.setOnClickListener {
            onCardClick(cardTokenizationStatus)
        }
    }

    override fun getItemCount(): Int {
        return cards.size
    }
}

class CardViewHolder(itemView: LinearLayout) : RecyclerView.ViewHolder(itemView)

