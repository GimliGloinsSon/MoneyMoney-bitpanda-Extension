-- Inofficial Bitpanda Extension (www.bitpanda.com) for MoneyMoney 
-- Fetches available data from Bitpanda API
-- 
-- Username: (anything)
-- Password: API-Key
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


WebBanking{version     = 1.00,
           url         = "https://api.bitpanda.com/v1/",
           services    = {"bitpanda"},
           description = "Loads FIATs from bitpanda"}

local connection = Connection()
local apiKey
local walletCurrency = "EUR"
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
  [40] = "Bitpanda Crypto Index [5",
  [41] = "Bitpanda Crypto Index [10",
  [42] = "Bitpanda Crypto Index [25",
}

function SupportsBank (protocol, bankCode)
    return protocol == ProtocolWebBanking and bankCode == "bitpanda"
end

function InitializeSession (protocol, bankCode, username, username2, password, username3)
    -- Login.
    user = username
    apiKey = password
end

function ListAccounts (knownAccounts)
    -- Return array of accounts.
    local accounts = {}

    -- FIAT Wallets
    local getAccounts = queryPrivate("fiatwallets").data
    for key, account in pairs(getAccounts) do
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
    local getDepots = queryPrivate("asset-wallets").data.attributes.cryptocoin.attributes.wallets
    for key, account in pairs(getDepots) do
      table.insert(accounts, 
      {
        name = account.attributes.name,
        owner = user,
        accountNumber = account.attributes.cryptocoin_id,
        bankCode = account.attributes.cryptocoin_symbol,
        currency = walletCurrency,
        portfolio = true,
        type = AccountTypePortfolio,
        subAccount = "cryptocoin"
      })
    end

    -- Indizes Wallets
    local getIndizes = queryPrivate("asset-wallets").data.attributes.index.index.attributes.wallets
    for key, account in pairs(getIndizes) do 
      table.insert(accounts, 
      {
        name = account.attributes.name,
        owner = user,
        accountNumber = account.attributes.cryptocoin_id,
        bankCode = account.attributes.cryptocoin_symbol,
        currency = walletCurrency,
        portfolio = true,
        type = AccountTypePortfolio,
        subAccount = "index.index"
      })
    end

    -- Commodity Wallets
    local getComm = queryPrivate("asset-wallets").data.attributes.commodity.metal.attributes.wallets
    for key, account in pairs(getComm) do
      table.insert(accounts, 
      {
        name = account.attributes.name,
        owner = user,
        accountNumber = account.attributes.cryptocoin_id,
        bankCode = account.attributes.cryptocoin_symbol,
        currency = walletCurrency,
        portfolio = true,
        type = AccountTypePortfolio,
        subAccount = "commodity.metal"
      })
    end

    return accounts
end

function RefreshAccount (account, since)
    MM.printStatus("Refreshing account " .. account.name)
    local sum = 0
    local getTrans = {}
    local t = {} -- List of transactions to return

    if account.portfolio then
      print("Portfolio")
      print(account.subAccount)
      if account.subAccount == "cryptocoin" then 
        getTrans = queryPrivate("asset-wallets").data.attributes.cryptocoin.attributes.wallets
      elseif account.subAccount == "index.index" then
        getTrans = queryPrivate("asset-wallets").data.attributes.index.index.attributes.wallets
      elseif account.subAccount == "commodity.metal" then
        getTrans = queryPrivate("asset-wallets").data.attributes.commodity.metal.attributes.wallets
      else
        return
      end
      for index, cryptTransaction in pairs(getTrans) do
        if cryptTransaction.attributes.cryptocoin_id == account.accountNumber then
          local transaction = transactionForCryptTransaction(cryptTransaction, account.accountNumber, account.currency)
          t[#t + 1] = transaction
        end
      end

      return {securities = t}      
    else
      getTrans = queryPrivate("fiatwallets/transactions")
      for index, fiatTransaction in pairs(getTrans.data) do
        local transaction = transactionForFiatTransaction(fiatTransaction, account.accountNumber, account.currency)
        if transaction == nil then
          print("Skipped transaction: " .. fiatTransaction.id)
        else
          t[#t + 1] = transaction
          if transaction.booked then
              sum = sum + transaction.amount
          end
        end
      end
  
      return {
          balance = sum,
          transactions = t
        }
    end

end

function transactionForCryptTransaction(transaction, accountId, currency)
    local symbol = transaction.attributes.cryptocoin_symbol
    local currPrice = tonumber(queryPrice(symbol, currency))
    local currQuant = tonumber(transaction.attributes.balance) 
    local currAmount = currPrice * currQuant 

    local calcPurchPrice = queryPurchPrice(accountId)

    t = {
      --String name: Bezeichnung des Wertpapiers
      name = transaction.attributes.name,
      --String isin: ISIN
      --String securityNumber: WKN
      securityNumber = symbol,
      --String market: Börse
      market = "bitpanda",
      --String currency: Währung bei Nominalbetrag oder nil bei Stückzahl
      currency = nil,
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
    
    if not (accountId == transaction.attributes.fiat_wallet_id) then
        return nil
    end

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
      purposeStr = fullAmount .. " " .. currency .. " - " .. transaction.attributes.fee .. " " .. currency .. " Gebuehren"
    end

    local isBooked = (transaction.attributes.status == "finished")
  
    t = {
      -- String name: Name des Auftraggebers/Zahlungsempfängers
      name = name,
      -- String accountNumber: Kontonummer oder IBAN des Auftraggebers/Zahlungsempfängers
      accountNumber = accountNumber,
      -- String bankCode: Bankzeitzahl oder BIC des Auftraggebers/Zahlungsempfängers
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
      -- Number textKeyExtension: Textschlüsselergänzung
      -- String purposeCode: SEPA-Verwendungsschlüssel
      -- String bookingKey: SWIFT-Buchungsschlüssel
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

function EndSession ()
    -- Logout.
end

function queryPurchPrice(accountId)
  local headers = {}
  headers["X-API-KEY"] = apiKey
  local path = "trades?type=buy"
  local amount = 0
  local buyPrice = 0

  content = connection:request("GET", url .. path, nil, nil, headers)

  buys = JSON(content):dictionary()

  for index, trades in pairs(buys.data) do
    if trades.attributes.cryptocoin_id == accountId then
      amount = amount + tonumber(trades.attributes.amount_cryptocoin)
      buyPrice = buyPrice + (tonumber(trades.attributes.amount_fiat) * tonumber(trades.attributes.fiat_to_eur_rate))
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

function queryPrice(symbol, currency)
  prices = connection:request("GET", "https://api.bitpanda.com/v1/ticker", nil, nil, nil)

  priceTable = JSON(prices):dictionary()
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