WebBanking{version     = 1.00,
           url         = "https://api.bitpanda.com/v1/",
           services    = {"bitpanda"},
           description = "Loads FIATs from bitpanda"}

local connection = Connection()
local apiKey

function SupportsBank (protocol, bankCode)
    return protocol == ProtocolWebBanking and bankCode == "bitpanda"
end

function InitializeSession (protocol, bankCode, username, username2, password, username3)
    -- Login.
    apiKey = password
end

function ListAccounts (knownAccounts)
    -- Return array of accounts.
    local getAccounts = queryPrivate("fiatwallets").data
    local accounts = {}
    for key, account in pairs(getAccounts) do
        accounts[#accounts + 1] = {
            name = account.attributes.name,
            owner = "Me",
            accountNumber = account.id,
            bankCode = account.type,
            currency = account.attributes.fiat_symbol,
            portfolio = false,
            type = AccountTypeSavings
        }
    end
    return accounts
end

function RefreshAccount (account, since)
    MM.printStatus("Refreshing account " .. account.name)
    local getTrans = queryPrivate("fiatwallets/transactions")
    local sum = 0

    local t = {} -- List of transactions to return
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

function transactionForFiatTransaction(transaction, accountId, currency)
    
    if not (accountId == transaction.attributes.fiat_wallet_id) then
        return nil
    end

    local isBooked = (transaction.attributes.status == "finished")
  
    t = {
      -- String name: Name des Auftraggebers/Zahlungsempfängers
      name = transaction.attributes.bank_account_details.attributes.holder,
      -- String accountNumber: Kontonummer oder IBAN des Auftraggebers/Zahlungsempfängers
      accountNumber = transaction.attributes.bank_account_details.attributes.iban,
      -- String bankCode: Bankzeitzahl oder BIC des Auftraggebers/Zahlungsempfängers
      bankCode = transaction.attributes.bank_account_details.attributes.bic,
      -- Number amount: Betrag
      amount = amountForFiatAmount(transaction.attributes.amount, transaction.attributes.in_or_out),
      -- String currency: Währung
      currency = currency,
      -- Number bookingDate: Buchungstag; Die Angabe erfolgt in Form eines POSIX-Zeitstempels.
      bookingDate = transaction.attributes.time.unix,
      -- Number valueDate: Wertstellungsdatum; Die Angabe erfolgt in Form eines POSIX-Zeitstempels.
      valueDate = transaction.attributes.time.unix,
      -- String purpose: Verwendungszweck; Mehrere Zeilen können durch Zeilenumbrüche ("\n") getrennt werden.
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

function httpBuildQuery(params)
    local str = ''
    for key, value in pairs(params) do
      str = str .. key .. "=" .. value .. "&"
    end
    str = str.sub(str, 1, -2)
    return str
end