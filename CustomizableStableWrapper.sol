// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title Multi-Stablecoin Wrapper
 * @title Обертка для нескольких стейблкоинов
 * @notice Wraps multiple stablecoins into a single token
 * @notice Объединяет несколько стейблкоинов в один токен
 */
contract MultiStableWrapper is ERC20, Ownable {
    using SafeERC20 for IERC20;
    
    // Список всех поддерживаемых стейблкоинов
    // List of all supported stablecoins
    address[] public supportedStables;
    
    // Маппинг для проверки поддерживаемых стейблкоинов
    // Mapping to check supported stablecoins
    mapping(address => bool) public isStablecoin;
    
    // Количество десятичных знаков (6 как у USDT)
    // Number of decimals (6 same as USDT)
    uint8 private constant _DECIMALS = 6;
    
    // Событие депозита
    // Deposit event
    event Deposit(address indexed user, address token, uint256 amount);
    
    // Событие вывода
    // Redeem event
    event Redeem(address indexed user, address token, uint256 amount);
    
    // Событие добавления стейблкоина
    // Stablecoin added event
    event StablecoinAdded(address token);
    
    // Событие удаления стейблкоина
    // Stablecoin removed event
    event StablecoinRemoved(address token);

    /**
     * @dev Конструктор с настраиваемыми параметрами
     * @dev Constructor with customizable parameters
     * @param tokenName Название вашего токена (например "MyStableToken")
     * @param tokenName Your token name (e.g. "MyStableToken")
     * @param tokenSymbol Символ токена (например "MST")
     * @param tokenSymbol Token symbol (e.g. "MST")
     * @param initialStables Начальные поддерживаемые стейблкоины
     * @param initialStables Initial supported stablecoins
     */
    constructor(
        string memory tokenName,
        string memory tokenSymbol,
        address[] memory initialStables
    ) ERC20(tokenName, tokenSymbol) Ownable(msg.sender) {
        for(uint i = 0; i < initialStables.length; i++) {
            // Защита от нулевых адресов и дубликатов
            // Protection against zero addresses and duplicates
            if(initialStables[i] != address(0) && !isStablecoin[initialStables[i]]) {
                supportedStables.push(initialStables[i]);
                isStablecoin[initialStables[i]] = true;
            }
        }
    }
    
    /**
     * @dev Возвращает количество десятичных знаков
     * @dev Returns the number of decimals
     */
    function decimals() public pure override returns (uint8) {
        return _DECIMALS;
    }
    
    /**
     * @dev Добавление нового стейблкоина (только владелец)
     * @dev Add new stablecoin (owner only)
     * @param token Адрес стейблкоина
     * @param token Stablecoin address
     */
    function addStablecoin(address token) external onlyOwner {
        require(token != address(0), "Invalid address/Неверный адрес");
        require(!isStablecoin[token], "Already added/Уже добавлен");
        
        supportedStables.push(token);
        isStablecoin[token] = true;
        emit StablecoinAdded(token);
    }
    
    /**
     * @dev Удаление стейблкоина (только владелец)
     * @dev Remove stablecoin (owner only)
     * @param token Адрес стейблкоина
     * @param token Stablecoin address
     */
    function removeStablecoin(address token) external onlyOwner {
        require(isStablecoin[token], "Not supported/Не поддерживается");
        
        // Удаляем из маппинга
        // Remove from mapping
        isStablecoin[token] = false;
        
        // Удаляем из массива
        // Remove from array
        for(uint i = 0; i < supportedStables.length; i++) {
            if(supportedStables[i] == token) {
                // Переносим последний элемент на место удаляемого
                // Move last element to current position
                supportedStables[i] = supportedStables[supportedStables.length - 1];
                
                // Удаляем последний элемент
                // Remove last element
                supportedStables.pop();
                break;
            }
        }
        
        emit StablecoinRemoved(token);
    }
    
    /**
     * @dev Депозит стейблкоина для получения обернутых токенов
     * @dev Deposit stablecoin to receive wrapped tokens
     * @param token Адрес стейблкоина
     * @param token Stablecoin address
     * @param amount Сумма для депозита
     * @param amount Amount to deposit
     */
    function deposit(address token, uint256 amount) external {
        require(isStablecoin[token], "Token not supported/Токен не поддерживается");
        require(amount > 0, "Amount must be positive/Сумма должна быть положительной");
        
        // Переводим токены от отправителя к контракту
        // Transfer tokens from sender to contract
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        
        // Выпускаем эквивалентное количество обернутых токенов
        // Mint equivalent amount of wrapped tokens
        _mint(msg.sender, amount);
        
        emit Deposit(msg.sender, token, amount);
    }
    
    /**
     * @dev Погашение обернутых токенов для получения стейблкоина
     * @dev Redeem wrapped tokens for stablecoin
     * @param token Адрес стейблкоина
     * @param token Stablecoin address
     * @param amount Сумма для погашения
     * @param amount Amount to redeem
     */
    function redeem(address token, uint256 amount) external {
        require(isStablecoin[token], "Token not supported/Токен не поддерживается");
        require(amount > 0, "Amount must be positive/Сумма должна быть положительной");
        
        // Проверяем наличие резервов
        // Check reserve balance
        uint256 reserveBalance = IERC20(token).balanceOf(address(this));
        require(reserveBalance >= amount, "Insufficient reserves/Недостаточно резервов");
        
        // Сжигаем обернутые токены
        // Burn wrapped tokens
        _burn(msg.sender, amount);
        
        // Возвращаем эквивалент в стейблкоине
        // Return equivalent in stablecoin
        IERC20(token).safeTransfer(msg.sender, amount);
        
        emit Redeem(msg.sender, token, amount);
    }
    
    /**
     * @dev Проверка баланса резервов для конкретного токена
     * @dev Check reserve balance for specific token
     * @param token Адрес стейблкоина
     * @param token Stablecoin address
     * @return Баланс резервов
     * @return Reserve balance
     */
    function reservesOf(address token) external view returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }
    
    /**
     * @dev Вывод резервов (только для владельца)
     * @dev Withdraw reserves (owner only)
     * @param token Адрес стейблкоина
     * @param token Stablecoin address
     * @param to Адрес получателя
     * @param to Recipient address
     */
    function withdrawReserves(address token, address to) external onlyOwner {
        require(to != address(0), "Invalid recipient/Неверный получатель");
        
        uint256 balance = IERC20(token).balanceOf(address(this));
        require(balance > 0, "No reserves/Нет резервов");
        
        IERC20(token).safeTransfer(to, balance);
    }
    
    /**
     * @dev Получение списка всех поддерживаемых стейблкоинов
     * @dev Get all supported stablecoins
     * @return Массив адресов стейблкоинов
     * @return Array of stablecoin addresses
     */
    function getAllSupportedStables() external view returns (address[] memory) {
        return supportedStables;
    }
}
