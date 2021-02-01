-- Inofficial Bitpanda Extension (www.bitpanda.com) for MoneyMoney 
-- Fetches available data from Bitpanda API
-- 
-- Username: API-Key
--
-- MIT License
--
-- Copyright (c) 2021 GimliGloinsSon
-- 
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
-- 
-- The above copyright notice and this permission notice shall be included in all
-- copies or substantial portions of the Software.
-- 
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
-- SOFTWARE.


WebBanking{version     = 1.01,
           url         = "https://api.bitpanda.com/v1/",
           services    = {"bitpanda"},
           description = "Loads FIATs, Krypto, Indizes and Commodities from bitpanda"}

local connection = Connection()
local apiKey
local walletCurrency = "EUR"
local pageSize = 50
local coinDict = {
  -- Krypto
  [1] = "Bitcoin",
  [3] = "Litecoin",
  [5] = "Etherum",
  [6] = "Lisk",
  [7] = "Dash",
  [8] = "Ripple",
  [9] = "Bitcoin Cash",
  [11] = "Pantos",
  [12] = "Komodo",
  [13] = "IOTA",
  [14] = "EOS",
  [15] = "OmiseGo",
  [16] = "Augur",
  [17] = "0x",
  [18] = "ZCash",
  [19] = "NEM",
  [20] = "Stellar",
  [21] = "Tezos",
  [22] = "Cardano",
  [23] = "NEO",
  [24] = "Etherum Classic",
  [25] = "Chainlink",
  [26] = "Waves",
  [27] = "Tether",
  [30] = "USD Coin",
  [31] = "Tron",
  [32] = "Cosmos",
  [33] = "Bitpanda Ecosystem Token",
  [34] = "Basic Attention Token",
  [37] = "Chiliz",
  [38] = "Tron",
  [39] = "Doge",
  [43] = "Qtum",
  [44] = "Vechain",
  [51] = "Polkadot",
  [52] = "Yearn.Finance",
  [53] = "Maker",
  [54] = "Compound",
  [55] = "Synthetix Network Token",
  [56] = "Uniswap",
  [57] = "Filecoin",
  [58] = "Aave",
  [59] = "Kyber Network",
  [60] = "Band Protocol",
  [61] = "REN",
  [63] = "UMA",
  -- Metals
  [28] = "Gold",
  [29] = "Silver",
  [35] = "Palladium",
  [36] = "Platinum",
  -- Indizes
  [40] = "Bitpanda Crypto Index 5",
  [41] = "Bitpanda Crypto Index 10",
  [42] = "Bitpanda Crypto Index 25",
}
local priceTable = {}
local typeList = {"buy", "sell"}
local allBuys = {}
local allSells = {}
local allTrades = {}
local allFiatTrans = {}
local allAssetWallets = {}
local allFiatWallets = {}


function SupportsBank (protocol, bankCode)
    return protocol == ProtocolWebBanking and bankCode == "bitpanda"
end

function InitializeSession (protocol, bankCode, username, username2, password, username3)
    -- Login.
    apiKey = username

    -- Wir holen uns erstmal alle Daten
    prices = connection:request("GET", "https://api.bitpanda.com/v1/ticker", nil, nil, nil)
    priceTable = JSON(prices):dictionary()

    for i, type in pairs(typeList) do
      trades = queryTrades(type)
      if type == "buy" then allBuys = trades
      else allSells = trades
      end
    end
    allTrades = unionTables(allBuys, allSells)
    allFiatTrans = queryFiatTrans()
    allAssetWallets = queryPrivate("asset-wallets")
    allFiatWallets = queryPrivate("fiatwallets")
  end

function ListAccounts (knownAccounts)
    -- Return array of accounts.
    local accounts = {}

    -- FIAT Wallets
    for key, account in pairs(allFiatWallets.data) do
      table.insert(accounts, 
      {
        name = account.attributes.name,
        owner = user,
        accountNumber = account.id,
        bankCode = account.type,
        currency = account.attributes.fiat_symbol,
        portfolio = false,
        type = AccountTypeSavings
      })
    end

    -- Crypto Wallets
    table.insert(accounts, 
      {
        name = "Krypto",
        owner = user,
        accountNumber = "Krypto Accounts",
        currency = walletCurrency,
        portfolio = true,
        type = AccountTypePortfolio,
        subAccount = "cryptocoin"
      })

    -- Indizes Wallets
    table.insert(accounts, 
      {
        name = "Indizes",
        owner = user,
        accountNumber = "Index Accounts",
        currency = walletCurrency,
        portfolio = true,
        type = AccountTypePortfolio,
        subAccount = "index.index"
      })
  
    -- Commodity Wallets
    table.insert(accounts, 
      {
        name = "Commodities",
        owner = user,
        accountNumber = "Metal Accounts",
        currency = walletCurrency,
        portfolio = true,
        type = AccountTypePortfolio,
        subAccount = "commodity.metal"
      })

    return accounts
end

function RefreshAccount (account, since)
    MM.printStatus("Refreshing account " .. account.name)
    local sum = 0
    local getTrans = {}
    local t = {} -- List of transactions to return

    -- transactions for Depot
    if account.portfolio then
      if account.subAccount == "cryptocoin" then 
        getTrans = allAssetWallets.data.attributes.cryptocoin.attributes.wallets
      elseif account.subAccount == "index.index" then
        getTrans = allAssetWallets.data.attributes.index.index.attributes.wallets
      elseif account.subAccount == "commodity.metal" then
        getTrans = allAssetWallets.data.attributes.commodity.metal.attributes.wallets
      else
        return
      end
      for index, cryptTransaction in pairs(getTrans) do
        if tonumber(cryptTransaction.attributes.balance) > 0 then
          local transaction = transactionForCryptTransaction(cryptTransaction, account.currency)
          t[#t + 1] = transaction
        end
      end
      return {securities = t}
      -- transactions for FIATS      
    else
      for index, fiatTransaction in pairs(allFiatTrans) do
        if account.accountNumber == fiatTransaction.attributes.fiat_wallet_id then
          local transaction = transactionForFiatTransaction(fiatTransaction, account.accountNumber, account.currency)
          t[#t + 1] = transaction
        end
      end
      --- Fiat transaction from buy/sell Indizes
      getIndizes = allAssetWallets.data.attributes.index.index.attributes.wallets
      for key, index in pairs(getIndizes) do
        --Buys
        listOfTransactions = getIndexBuys(account.currency, index.id, index.attributes.cryptocoin_id, account.accountNumber, "buy")
        if (#listOfTransactions) > 0 then
          for i = 1, #listOfTransactions, 1 do
            t[#t + 1] = listOfTransactions[i]
          end
        end
        --Sells
        listOfTransactions = getIndexBuys(account.currency, index.id, index.attributes.cryptocoin_id, account.accountNumber, "sell")
        if (#listOfTransactions) > 0 then
          for i = 1, #listOfTransactions, 1 do
            t[#t + 1] = listOfTransactions[i]
          end
        end
      end

      -- Get Balance
      for index, fiatBalance in pairs(allFiatWallets.data) do
        if fiatBalance.id == account.accountNumber then
          sum = fiatBalance.attributes.balance
        end
      end
  
      return {
          balance = sum,
          transactions = t
        }
    end

end

function transactionForCryptTransaction(transaction, currency)
    local symbol = transaction.attributes.cryptocoin_symbol
    local currPrice = tonumber(queryPrice(symbol, currency))
    local currQuant = tonumber(transaction.attributes.balance) 
    local currAmount = currPrice * currQuant 

    local calcPurchPrice = 0
    local calcCurrency = nil
    
    -- Calculation for Indizes
    if transaction.attributes.is_index then
      calcCurrency = currency
      calcPurchPrice = queryPurchPrice(transaction.id, "index")
      currPrice = currQuant / calcPurchPrice * 100
      currAmount = currQuant
      currQuant = calcPurchPrice
      calcPurchPrice = 100
    else 
      calcPurchPrice = queryPurchPrice(transaction.attributes.cryptocoin_id, "crypt")
    end

    t = {
      --String name: Bezeichnung des Wertpapiers
      name = transaction.attributes.name,
      --String isin: ISIN
      --String securityNumber: WKN
      securityNumber = symbol,
      --String market: Börse
      market = "bitpanda",
      --String currency: Währung bei Nominalbetrag oder nil bei Stückzahl
      currency = calcCurrency,
      --Number quantity: Nominalbetrag oder Stückzahl
      quantity = currQuant,
      --Number amount: Wert der Depotposition in Kontowährung
      amount = currAmount,
      --Number originalCurrencyAmount: Wert der Depotposition in Originalwährung
      --String currencyOfOriginalAmount: Originalwährung
      --Number exchangeRate: Wechselkurs zum Kaufzeitpunkt
      --Number tradeTimestamp: Notierungszeitpunkt; Die Angabe erfolgt in Form eines POSIX-Zeitstempels.
      tradeTimestamp = os.time(),
      --Number price: Aktueller Preis oder Kurs
      price = currPrice,
      --String currencyOfPrice: Von der Kontowährung abweichende Währung des Preises
      --Number purchasePrice: Kaufpreis oder Kaufkurs
      purchasePrice = calcPurchPrice
      --String currencyOfPurchasePrice: Von der Kontowährung abweichende Währung des Kaufpreises
    }

    return t
end

function transactionForFiatTransaction(transaction, accountId, currency)
    local name = "unknown"
    local accountNumber = "unkown IBAN"
    local bankCode = "unknown BIC"
    local cryptId = 0
    local asset = "unknown Asset"
    local purposeStr = ""  

    if not (transaction.attributes.bank_account_details == nil) then
      name = transaction.attributes.bank_account_details.attributes.holder
      accountNumber = transaction.attributes.bank_account_details.attributes.iban
      bankCode = transaction.attributes.bank_account_details.attributes.bic
    end

    if not (transaction.attributes.ccard_digits == nil) then
      name = "Credit Card"
      accountNumber = transaction.attributes.ccard_digits
    end

    if not (transaction.attributes.trade == nil) then
      cryptId = tonumber(transaction.attributes.trade.attributes.cryptocoin_id)
      asset = coinDict[cryptId]
      if not (asset == nil) then
        name = transaction.attributes.trade.attributes.type .. ": " .. coinDict[cryptId]
      else
        name = transaction.attributes.trade.attributes.type .. ": Unknown Asset"
      end
    end

    if tonumber(transaction.attributes.fee) > 0 then
      fullAmount = tonumber(transaction.attributes.amount) + tonumber(transaction.attributes.fee)
      purposeStr = fullAmount .. " " .. currency .. " - " .. transaction.attributes.fee .. " " .. currency .. " fee"
    end

    local isBooked = (transaction.attributes.status == "finished")

    if transaction.attributes.is_savings then
      purposeStr = purposeStr .. "Booking reserved for savings plan. Amount not available!"
    end
  
    t = {
      -- String name: Name des Auftraggebers/Zahlungsempfängers
      name = name,
      -- String accountNumber: Kontonummer oder IBAN des Auftraggebers/Zahlungsempfängers
      accountNumber = accountNumber,
      -- String bankCode: Bankleitzahl oder BIC des Auftraggebers/Zahlungsempfängers
      bankCode = bankCode,
      -- Number amount: Betrag
      amount = amountForFiatAmount(transaction.attributes.amount, transaction.attributes.in_or_out),
      -- String currency: Währung
      currency = currency,
      -- Number bookingDate: Buchungstag; Die Angabe erfolgt in Form eines POSIX-Zeitstempels.
      bookingDate = transaction.attributes.time.unix,
      -- Number valueDate: Wertstellungsdatum; Die Angabe erfolgt in Form eines POSIX-Zeitstempels.
      valueDate = transaction.attributes.time.unix,
      -- String purpose: Verwendungszweck; Mehrere Zeilen können durch Zeilenumbrüche ("\n") getrennt werden.
      purpose = purposeStr,
      -- Number transactionCode: Geschäftsvorfallcode
      -- Number textKeyExtension: Textschlüsselergänzung
      -- String purposeCode: SEPA-Verwendungsschlüssel
      -- String bookingKey: SWIFT-Buchungsschlüssel
      -- String bookingText: Umsatzart
      bookingText = transaction.attributes.type,
      -- String primanotaNumber: Primanota-Nummer
      -- String customerReference: SEPA-Einreicherreferenz
      -- String endToEndReference: SEPA-Ende-zu-Ende-Referenz
      -- String mandateReference: SEPA-Mandatsreferenz
      -- String creditorId: SEPA-Gläubiger-ID
      -- String returnReason: Rückgabegrund
      -- Boolean booked: Gebuchter oder vorgemerkter Umsatz
      booked = isBooked,
    }
    return t
  end

  function amountForFiatAmount(amount, in_or_out)
    if in_or_out == "incoming" then
        return amount
    else
        return amount * -1
    end
end        

function getIndexBuys(currency, currIndex, currCryptId, accountId, type)
  currIndexName = coinDict[tonumber(currCryptId)]
  local firstTrans = true
  local currDate = nil
  betrag = 0
  trans = {}
  t = {}
  bookingText = "Buy"
  factor = -1
  trades = allBuys

  if type == "sell" then
    bookingText = "Sell"
    factor = 1
    trades = allSells
  end

  for key, trade in pairs(trades) do
    if trade.attributes.wallet_id == currIndex and trade.attributes.fiat_wallet_id == accountId then
      if (currDate ~= string.sub(trade.attributes.time.date_iso8601, 1, 13) and firstTrans) then
          currDate = string.sub(trade.attributes.time.date_iso8601, 1, 13)
          firstTrans = false
          betrag = betrag + tonumber(trade.attributes.amount_fiat)
      elseif currDate ~= string.sub(trade.attributes.time.date_iso8601, 1, 13) and not firstTrans then
          trans = {
              name = bookingText .. ": " .. currIndexName,
              accountNumber = "unkown IBAN",
              bankCode = "unknown BIC",
              amount = betrag * factor,
              currency = currency,
              bookingDate = dateToTimestamp(string.sub(currDate, 1, 10)),
              bookingText = bookingText,
              booked = true
          }
          currDate = string.sub(trade.attributes.time.date_iso8601, 1, 13)
          betrag = tonumber(trade.attributes.amount_fiat)
          t[#t + 1] = trans                
      else
          betrag = betrag + tonumber(trade.attributes.amount_fiat)
      end
    end
  end
    
  if betrag > 0 then
    trans = {
        name = bookingText .. ": " .. currIndexName,
        accountNumber = "unkown IBAN",
        bankCode = "unknown BIC",
        amount = betrag * factor,
        currency = currency,
        bookingDate = dateToTimestamp(string.sub(currDate, 1, 10)),
        purpose = purposeStr,
        bookingText = bookingText,
        booked = true
    }
    t[#t + 1] = trans
  end
  return t
end

function EndSession ()
    -- Logout.
end

function queryPurchPrice(accountId, type)
  local amount = 0
  local buyPrice = 0

  for index, trades in pairs(allTrades) do
    if trades.attributes.cryptocoin_id == accountId and type == "crypt" then
      if trades.attributes.type == "buy" then
        amount = amount + tonumber(trades.attributes.amount_cryptocoin)
        buyPrice = buyPrice + (tonumber(trades.attributes.amount_fiat) * tonumber(trades.attributes.fiat_to_eur_rate))
      else
        amount = amount - tonumber(trades.attributes.amount_cryptocoin)
        buyPrice = buyPrice - (tonumber(trades.attributes.amount_fiat) * tonumber(trades.attributes.fiat_to_eur_rate))
      end
    elseif trades.attributes.wallet_id == accountId and type == "index" then
      if trades.attributes.type == "buy" then
        buyPrice = buyPrice + tonumber(trades.attributes.amount_fiat)
      else
        buyPrice = buyPrice - tonumber(trades.attributes.amount_fiat)
      end
      amount = 1
    end
  end

  -- Wenn Cryptcoin_id == 33 --> prüfen, ob Coin für Fee verwendet wurde
  if accountId == "33" then
    for index, trades in pairs(allTrades) do
      if trades.attributes.best_fee_collection ~= nil then
        amount = amount - tonumber(trades.attributes.best_fee_collection.attributes.wallet_transaction.attributes.fee)
        buyPrice = buyPrice - tonumber(trades.attributes.best_fee_collection.attributes.best_used_price_eur)
      end
    end
  end

  if amount > 0 then
    return buyPrice / amount
  else
    return 0
  end
end

function queryPrivate(method, params)
    local path = method
  
    if not (params == nil) then
      local queryParams = httpBuildQuery(params)
      if string.len(queryParams) > 0 then
        path = path .. "?" .. queryParams
      end
    end
  
    local headers = {}
    headers["X-API-KEY"] = apiKey
  
    content = connection:request("GET", url .. path, nil, nil, headers)
  
    return JSON(content):dictionary()
end

function queryTrades(type)
  local nextPage = 1
  local tradeTable = {}
  while nextPage ~= nil do
    tradeData = queryPrivate("trades", {type = type, page = nextPage, page_size = pageSize})
    trades = tradeData.data
    if #trades > 0 then
      tradeTable = unionTables(tradeTable, trades)
    end
    if tradeData.links.next ~= nil then
      nextPage = nextPage + 1
    else  
      nextPage = nil
    end
  end
  return tradeTable
end

function queryFiatTrans()
  local nextPage = 1
  local transTable = {}
  while nextPage ~= nil do
    transData = queryPrivate("fiatwallets/transactions", {page = nextPage, page_size = pageSize})
    trans = transData.data
    if #trans > 0 then
      transTable = unionTables(transTable, trans)
    end
    if transData.links.next ~= nil then
      nextPage = nextPage + 1
    else  
      nextPage = nil
    end
  end
  return transTable
end


function queryPrice(symbol, currency)
  return priceTable[symbol][currency]
end

function httpBuildQuery(params)
    local str = ''
    for key, value in pairs(params) do
      str = str .. key .. "=" .. value .. "&"
    end
    str = str.sub(str, 1, -2)
    return str
end

function dateToTimestamp(date)
  local year, month, day=date:match("(%d+)-(%d+)-(%d+)")

  timeSta = os.time({
      year = tonumber(year),
      month = tonumber(month),
      day = tonumber(day)
  })
  return timeSta
end

function unionTables ( a, b )
  local result = {}
  for k,v in pairs ( a ) do
      table.insert( result, v )
  end
  for k,v in pairs ( b ) do
       table.insert( result, v )
  end
  return result
end