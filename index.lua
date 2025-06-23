-- Установка ширины игрового экрана
screenWidth = 480
-- Установка высоты игрового экрана
screenHeight = 272

-- Создание объекта игрока с начальными параметрами
player = {
    x = screenWidth / 2,          -- Начальная позиция по X (центр экрана)
    y = screenHeight - 40,        -- Позиция по Y (ближе к низу экрана)
    width = 32,                   -- Ширина спрайта игрока
    height = 16,                  -- Высота спрайта игрока
    speed = 4,                    -- Скорость перемещения игрока
    bullets = {},                 -- Таблица для хранения пуль игрока
    lastShot = 0,                 -- Время последнего выстрела
    lives = 1                     -- Количество жизней игрока
}

-- Таблица для хранения пуль врагов
enemyBullets = {}

-- Таблица для хранения врагов
enemies = {}
-- Базовая скорость движения врагов
enemyBaseSpeed = 0.4
-- Направление движения врагов (1 - вправо, -1 - влево)
enemyDirection = 1
-- Расстояние, на которое опускаются враги при достижении границы
enemyStepDown = 10
-- Таймер перед началом стрельбы врагов
enemyShootCooldown = 100

-- Таблица для хранения укрытий
cover = {}

-- Переменная для хранения босса (изначально отсутствует)
boss = nil

-- Текущее состояние игры (меню, игра, управление)
state = "menu"
-- Флаг окончания игры
gameOver = false

-- Счет игрока
score = 0
-- Номер текущей волны врагов
waveNumber = 1

-- Переменные для обработки нажатия кнопки START
local lastStart = false          -- Предыдущее состояние кнопки START
local startPressedHandled = false -- Флаг обработки нажатия START

-- Функция инициализации врагов
function initEnemies()
    -- Очистка таблицы врагов
    enemies = {}
    -- Установка параметров врагов
    local enemyWidth = 30        -- Ширина спрайта врага
    local enemyHeight = 20       -- Высота спрайта врага
    local padding = 10           -- Расстояние между врагами
    local startX = 40            -- Начальная позиция по X
    local startY = 50            -- Начальная позиция по Y
    -- Количество рядов врагов (не более 3)
    local rows = math.min(waveNumber, 3)
    -- Создание сетки врагов
    for row = 0, rows - 1 do               -- Для каждого ряда
        for i = 0, 7 do                    -- 8 врагов в ряду
            -- Добавление врага в таблицу
            table.insert(enemies, {
                x = startX + i * (enemyWidth + padding),  -- Позиция X
                y = startY + row * (enemyHeight + 10),    -- Позиция Y
                width = enemyWidth,       -- Ширина
                height = enemyHeight      -- Высота
            })
        end
    end
    -- Сброс направления движения врагов
    enemyDirection = 1
end

-- Функция инициализации укрытий
function initCover()
    -- Очистка таблицы укрытий
    cover = {}
    -- Случайное количество укрытий (от 3 до 4)
    local numCover = math.random(3, 4)
    -- Параметры укрытий
    local coverWidth = 50        -- Ширина укрытия
    local coverHeight = 20       -- Высота укрытия
    -- Создание укрытий
    for i = 1, numCover do
        -- Случайная позиция по X
        local xPos = math.random(5, screenWidth - coverWidth - 5)
        -- Позиция по Y (фиксированная над игроком)
        local yPos = player.y - 60
        -- Добавление укрытия в таблицу
        table.insert(cover, {
            x = xPos,            -- Позиция X
            y = yPos,            -- Позиция Y
            width = coverWidth,   -- Ширина
            height = coverHeight, -- Высота
            hp = 5,              -- Прочность укрытия
            cracks = {}          -- Таблица для трещин
        })
    end
end

-- Функция сброса игры
function resetGame()
    -- Сброс позиции игрока
    player.x = screenWidth / 2
    -- Восстановление жизней
    player.lives = 1
    -- Очистка пуль игрока
    player.bullets = {}
    -- Очистка пуль врагов
    enemyBullets = {}
    -- Сброс номера волны
    waveNumber = 1
    -- Удаление босса
    boss = nil
    -- Инициализация врагов
    initEnemies()
    -- Инициализация укрытий
    initCover()
    -- Сброс флага окончания игры
    gameOver = false
    -- Сброс счета
    score = 0
end

-- Функция отрисовки укрытий
function drawCover()
    -- Перебор всех укрытий
    for _, c in ipairs(cover) do
        -- Проверка, что укрытие не разрушено
        if c.hp > 0 then
            -- Отрисовка укрытия (зеленый прямоугольник)
            screen:fillRect(c.x, c.y, c.width, c.height, Color.new(0, 150, 0))
            -- Отрисовка трещин на укрытии
            for _, crack in ipairs(c.cracks) do
                local points = crack.points
                -- Отрисовка линий между точками трещины
                for i = 1, #points - 1 do
                    local x1, y1 = points[i][1], points[i][2]
                    local x2, y2 = points[i + 1][1], points[i + 1][2]
                    screen:drawLine(x1, y1, x2, y2, Color.new(0, 0, 0))
                end
            end
        end
    end
end

-- Функция проверки попадания пули в укрытие
function bulletHitsCover(bullet, coverObj)
    -- Проверка коллизии AABB (прямоугольник-прямоугольник)
    return bullet.x > coverObj.x and bullet.x < coverObj.x + coverObj.width and
           bullet.y > coverObj.y and bullet.y < coverObj.y + coverObj.height
end

-- Функция создания трещины на укрытии
function createLightningCrack(coverObj)
    -- Проверка максимального количества трещин (не более 5)
    if #coverObj.cracks >= 5 then return end
    -- Случайная начальная точка трещины
    local startX = math.random(coverObj.x + 5, coverObj.x + coverObj.width - 10)
    local startY = math.random(coverObj.y + 5, coverObj.y + coverObj.height - 10)
    -- Параметры трещины
    local length = math.random(20, 35)      -- Длина трещины
    local segments = math.random(5, 7)      -- Количество сегментов
    local points = {}                       -- Точки трещины
    -- Добавление начальной точки
    table.insert(points, {startX, startY})
    local x, y = startX, startY
    local direction = 1                     -- Направление изгиба
    -- Создание сегментов трещины
    for i = 1, segments do
        -- Перемещение по X
        x = x + length / segments
        -- Случайное перемещение по Y с чередованием направления
        y = y + direction * math.random(3, 7)
        -- Ограничение Y в пределах укрытия
        y = math.max(coverObj.y + 2, math.min(y, coverObj.y + coverObj.height - 2))
        -- Добавление точки
        table.insert(points, {x, y})
        -- Смена направления
        direction = -direction
    end
    -- Добавление трещины в укрытие
    table.insert(coverObj.cracks, { points = points })
end

-- Основная функция обновления игрового состояния
function updateGame()
    -- Чтение состояния контроллера
    local pad = Controls.read()
    local currentStart = pad:start()

    -- Обработка нажатия START (пауза/меню)
    if currentStart and not lastStart and not startPressedHandled then
        state = "menu"
        startPressedHandled = true
        lastStart = currentStart
        return
    elseif not currentStart then
        startPressedHandled = false
    end
    lastStart = currentStart

    -- Обработка состояния Game Over
    if gameOver then
        if currentStart and not startPressedHandled then
            resetGame()
            state = "game"
            startPressedHandled = true
        end
        return
    end

    -- Управление игроком
    if pad:l() then player.x = math.max(0, player.x - player.speed) end  -- Движение влево
    if pad:r() then player.x = math.min(screenWidth - player.width, player.x + player.speed) end  -- Движение вправо

    -- Обработка выстрелов игрока
    if pad:cross() and os.clock() - player.lastShot > 0.3 then
        -- Создание новой пули
        table.insert(player.bullets, { x = player.x + player.width / 2 - 1, y = player.y })
        player.lastShot = os.clock()  -- Обновление времени последнего выстрела
    end

    -- Обновление пуль игрока
    local i = 1
    while i <= #player.bullets do
        local b = player.bullets[i]
        b.y = b.y - 5  -- Перемещение пули вверх

        local hit = false  -- Флаг попадания

        -- Проверка попадания в укрытия
        for _, c in ipairs(cover) do
            if c.hp > 0 and bulletHitsCover(b, c) then
                c.hp = c.hp - 1             -- Уменьшение прочности укрытия
                createLightningCrack(c)      -- Создание трещины
                hit = true                   -- Установка флага попадания
                break                        -- Прерывание цикла
            end
        end

        -- Проверка попадания во врагов (если не было попадания в укрытие)
        if not hit then
            -- Перебор врагов в обратном порядке для безопасного удаления
            for j = #enemies, 1, -1 do
                local e = enemies[j]
                if b.x > e.x and b.x < e.x + e.width and
                   b.y > e.y and b.y < e.y + e.height then
                    table.remove(enemies, j)  -- Удаление врага
                    hit = true
                    score = score + 10        -- Начисление очков
                    break
                end
            end
        end

        -- Проверка попадания в босса (если не было других попаданий)
        if not hit and boss then
            if b.x > boss.x and b.x < boss.x + boss.width and
               b.y > boss.y and b.y < boss.y + boss.height then
                boss.hp = boss.hp - 1         -- Уменьшение HP босса
                hit = true
                if boss.hp <= 0 then          -- Проверка смерти босса
                    score = score + 100       -- Большой бонус за босса
                    boss = nil                -- Удаление босса
                end
            end
        end

        -- Проверка выхода пули за границы экрана
        if not hit and b.y < 0 then
            hit = true
        end

        -- Удаление пули при попадании или выходе за экран
        if hit then
            table.remove(player.bullets, i)
        else
            i = i + 1  -- Переход к следующей пуле
        end
    end

    -- Обновление босса
    if boss then
        -- Движение босса
        boss.x = boss.x + 0.5 * math.sin(os.clock() * 2)
        -- Случайная стрельба босса
        if math.random() < 0.02 then
            -- Создание нескольких пуль
            for i = 1, math.random(3, 4) do
                table.insert(enemyBullets, {
                    x = boss.x + boss.width / 2 + math.random(-20, 20),  -- Случайное смещение по X
                    y = boss.y + boss.height                             -- Позиция по Y
                })
            end
        end
    else
        -- Поиск самого нижнего врага
        local maxEnemyY = 0
        for _, e in ipairs(enemies) do
            if e.y > maxEnemyY then maxEnemyY = e.y end
        end

        -- Расчет скорости врагов (увеличивается при приближении к игроку)
        local maxSpeed = 1.5
        local speedFactor = maxEnemyY / screenHeight
        local enemySpeed = enemyBaseSpeed + speedFactor * (maxSpeed - enemyBaseSpeed)

        -- Проверка необходимости смещения вниз
        local moveDown = false
        for _, e in ipairs(enemies) do
            e.x = e.x + enemySpeed * enemyDirection  -- Движение врага
            -- Проверка достижения границы экрана
            if e.x + e.width >= screenWidth - 5 and enemyDirection == 1 then moveDown = true end
            if e.x <= 5 and enemyDirection == -1 then moveDown = true end
        end

        -- Обработка смещения вниз
        if moveDown then
            enemyDirection = -enemyDirection  -- Смена направления
            for _, e in ipairs(enemies) do
                e.y = e.y + enemyStepDown  -- Смещение вниз
                -- Проверка поражения (враги достигли игрока)
                if e.y + e.height >= player.y then gameOver = true end
            end
        end
    end

    -- Обновление пуль врагов
    local i = 1
    while i <= #enemyBullets do
        local b = enemyBullets[i]
        b.y = b.y + 2  -- Перемещение пули вниз

        local hit = false  -- Флаг попадания

        -- Проверка попадания в укрытия
        for _, c in ipairs(cover) do
            if c.hp > 0 and bulletHitsCover(b, c) then
                c.hp = c.hp - 1             -- Уменьшение прочности укрытия
                createLightningCrack(c)      -- Создание трещины
                hit = true                   -- Установка флага попадания
                break                        -- Прерывание цикла
            end
        end

        -- Проверка попадания в игрока
        if not hit and b.x > player.x and b.x < player.x + player.width and
           b.y > player.y and b.y < player.y + player.height then
            gameOver = true  -- Завершение игры
            hit = true
        end

        -- Проверка выхода пули за границы экрана
        if not hit and b.y > screenHeight then hit = true end

        -- Удаление пули при попадании или выходе за экран
        if hit then
            table.remove(enemyBullets, i)
        else
            i = i + 1  -- Переход к следующей пуле
        end
    end

    -- Обработка стрельбы врагов
    enemyShootCooldown = enemyShootCooldown - 1  -- Уменьшение таймера
    if enemyShootCooldown <= 0 and #enemies > 0 then
        local eligibleShooters = {}  -- Враги, которые могут стрелять
        for _, e in ipairs(enemies) do
            local blocked = false
            -- Проверка, не закрыт ли враг другими врагами сверху
            for _, other in ipairs(enemies) do
                if other ~= e and other.x == e.x and other.y > e.y then
                    blocked = true
                    break
                end
            end
            if not blocked then table.insert(eligibleShooters, e) end
        end
        -- Если есть враги, которые могут стрелять
        if #eligibleShooters > 0 then
            -- Выбор случайного стрелка
            local shooter = eligibleShooters[math.random(#eligibleShooters)]
            -- Создание пули
            table.insert(enemyBullets, { 
                x = shooter.x + shooter.width / 2,  -- Позиция X (центр врага)
                y = shooter.y + shooter.height     -- Позиция Y (низ врага)
            })
            enemyShootCooldown = 30  -- Установка таймера перезарядки
        end
    end

    -- Обработка перехода к следующей волне
    if #enemies == 0 and boss == nil then
        -- Начисление бонуса за уцелевшие укрытия
        local blocksSaved = 0
        for _, c in ipairs(cover) do
            if c.hp > 0 then blocksSaved = blocksSaved + 1 end
        end
        score = score + blocksSaved * 5

        -- Увеличение номера волны
        waveNumber = waveNumber + 1
        -- Проверка на появление босса (каждая 3 волна)
        if waveNumber == 4 then
            -- Создание босса
            boss = {
                x = screenWidth / 2 - 50,  -- Позиция X (центр экрана)
                y = 50,                    -- Позиция Y (верх экрана)
                width = 100,               -- Ширина
                height = 40,               -- Высота
                hp = 20                    -- Здоровье
            }
        else
            -- Сброс номера волны после 3
            if waveNumber > 3 then waveNumber = 1 end
            -- Инициализация новой волны врагов
            initEnemies()
            -- Создание новых укрытий
            initCover()
        end
    end
end

-- Функция обновления меню
function updateMenu()
    local pad = Controls.read()
    local currentStart = pad:start()
    -- Обработка нажатия START (начало игры)
    if currentStart and not lastStart and not startPressedHandled then
        resetGame()
        state = "game"
        startPressedHandled = true
    elseif not currentStart then
        startPressedHandled = false
    end
    lastStart = currentStart

    -- Обработка нажатия SELECT (переход к управлению)
    if pad:select() then state = "controls" end
end

-- Функция обновления экрана управления
function updateControls()
    local pad = Controls.read()
    -- Возврат в меню при отпускании SELECT
    if not pad:select() then state = "menu" end
end

-- Функция отрисовки меню
function drawMenu()
    -- Очистка экрана (черный цвет)
    screen:fillRect(0, 0, screenWidth, screenHeight, Color.new(0, 0, 0))
    -- Текст "PRESS START TO START"
    screen:print(160, 100, "PRESS START TO START", Color.new(255, 255, 255))
    -- Текст "HOLD SELECT TO SHOW CONTROLS"
    screen:print(130, 130, "HOLD SELECT TO SHOW CONTROLS", Color.new(255, 255, 255))
    -- Обновление экрана
    screen.flip()
end

-- Функция отрисовки экрана управления
function drawControls()
    -- Очистка экрана (черный цвет)
    screen:fillRect(0, 0, screenWidth, screenHeight, Color.new(0, 0, 0))
    -- Информация об управлении
    screen:print(50, 80, "LEFT / RIGHT: Move platform", Color.new(255, 255, 255))
    screen:print(50, 110, "X (Cross): Shoot", Color.new(255, 255, 255))
    screen:print(50, 140, "START: Pause / Return to menu", Color.new(255, 255, 255))
    screen:print(50, 170, "SELECT: Show controls", Color.new(255, 255, 255))
    -- Обновление экрана
    screen.flip()
end

-- Функция отрисовки игрового экрана
function drawGame()
    -- Очистка экрана (черный цвет)
    screen:fillRect(0, 0, screenWidth, screenHeight, Color.new(0, 0, 0))

    -- Проверка состояния Game Over
    if gameOver then
        -- Подготовка текстов
        local goText = "GAME OVER"
        local scoreText = "Score: " .. tostring(score)
        local waveText = "Wave: " .. tostring(waveNumber)
        local restartText = "PRESS START TO RESTART"

        -- Расчет позиций текста (центрирование)
        local goX = (screenWidth - string.len(goText) * 8) / 2
        local scoreX = (screenWidth - string.len(scoreText) * 8) / 2
        local waveX = (screenWidth - string.len(waveText) * 8) / 2
        local restartX = (screenWidth - string.len(restartText) * 8) / 2

        local centerY = screenHeight / 2  -- Центр экрана по Y

        -- Отрисовка текстов
        screen:print(goX, centerY - 30, goText, Color.new(255, 0, 0))       -- Красный "GAME OVER"
        screen:print(scoreX, centerY - 10, scoreText, Color.new(255, 255, 255)) -- Белый счет
        screen:print(waveX, centerY + 10, waveText, Color.new(255, 255, 255))   -- Белый номер волны
        screen:print(restartX, centerY + 30, restartText, Color.new(255, 255, 255)) -- Белый текст рестарта
    else
        -- Отрисовка игрока (белый прямоугольник)
        screen:fillRect(player.x, player.y, player.width, player.height, Color.new(255, 255, 255))

        -- Отрисовка пуль игрока (желтые прямоугольники)
        for _, b in ipairs(player.bullets) do
            screen:fillRect(b.x, b.y, 2, 5, Color.new(255, 255, 0))
        end

        -- Отрисовка врагов (красные прямоугольники)
        for _, e in ipairs(enemies) do
            screen:fillRect(e.x, e.y, e.width, e.height, Color.new(255, 0, 0))
        end

        -- Отрисовка босса (пурпурный прямоугольник)
        if boss then
            screen:fillRect(boss.x, boss.y, boss.width, boss.height, Color.new(255, 0, 255))
        end

        -- Отрисовка пуль врагов (зеленые прямоугольники)
        for _, b in ipairs(enemyBullets) do
            screen:fillRect(b.x, b.y, 2, 5, Color.new(0, 255, 0))
        end

        -- Отрисовка укрытий
        drawCover()

        -- Отрисовка интерфейса (счет и номер волны)
        screen:print(5, 5, "Score: " .. tostring(score), Color.new(255, 255, 255))
        screen:print(5, 20, "Wave: " .. tostring(waveNumber), Color.new(255, 255, 255))
    end

    -- Обновление экрана
    screen.flip()
end

-- Инициализация игры
resetGame()

-- Главный игровой цикл
while true do
    -- Обработка текущего состояния
    if state == "menu" then
        drawMenu()    -- Отрисовка меню
        updateMenu()  -- Обновление меню
    elseif state == "game" then
        updateGame()  -- Обновление игровой логики
        drawGame()    -- Отрисовка игры
    elseif state == "controls" then
        drawControls()  -- Отрисовка управления
        updateControls() -- Обновление управления
    end
end