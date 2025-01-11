-- Create the database if it doesn't exist
CREATE DATABASE IF NOT EXISTS user_management;
USE user_management;

-- Create users table (main user information)
CREATE TABLE IF NOT EXISTS users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    password VARCHAR(64) NOT NULL,  -- SHA-256 hash is 64 characters
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create user_preferences table (for user-specific settings)
CREATE TABLE IF NOT EXISTS user_preferences (
    user_id INT PRIMARY KEY,
    theme VARCHAR(20) DEFAULT 'light',
    language VARCHAR(10) DEFAULT 'en',
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- Create calendar_events table (for user-specific calendar)
CREATE TABLE IF NOT EXISTS calendar_events (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    title VARCHAR(100) NOT NULL,
    description TEXT,
    event_date DATE NOT NULL,
    event_time TIME,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- Create notes table (for user-specific notes)
CREATE TABLE IF NOT EXISTS notes (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    title VARCHAR(100) NOT NULL,
    content TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- Create custom_data table (for any additional user-specific data)
CREATE TABLE IF NOT EXISTS custom_data (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    data_type VARCHAR(50) NOT NULL,
    data_value TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- Create function to check if username exists
DELIMITER //
CREATE FUNCTION IsUsernameExists(
    p_username VARCHAR(50)
) 
RETURNS BOOLEAN
DETERMINISTIC
BEGIN
    DECLARE user_count INT;
    SELECT COUNT(*) INTO user_count FROM users WHERE username = p_username;
    RETURN user_count > 0;
END //

-- Create stored procedure for user registration with validation
CREATE PROCEDURE RegisterUser(
    IN p_username VARCHAR(50),
    IN p_password VARCHAR(64)
)
BEGIN
    DECLARE new_user_id INT;
    
    IF NOT IsUsernameExists(p_username) THEN
        INSERT INTO users (username, password)
        VALUES (p_username, p_password);
        
        -- Get the new user's ID
        SET new_user_id = LAST_INSERT_ID();
        
        -- Create default preferences for the new user
        INSERT INTO user_preferences (user_id) VALUES (new_user_id);
        
        SELECT 'User registered successfully' as message;
    ELSE
        SELECT 'Username already exists' as message;
    END IF;
END //

-- Create stored procedure for login verification
CREATE PROCEDURE VerifyLogin(
    IN p_username VARCHAR(50),
    IN p_password VARCHAR(64)
)
BEGIN
    DECLARE user_exists BOOLEAN;
    SELECT COUNT(*) > 0 INTO user_exists
    FROM users
    WHERE username = p_username AND password = p_password;

    IF user_exists THEN
        SELECT u.id, u.username, p.theme, p.language, 'Login successful' as message
        FROM users u
        LEFT JOIN user_preferences p ON u.id = p.user_id
        WHERE u.username = p_username;
    ELSE
        SELECT 'Invalid username or password' as message;
    END IF;
END //

-- Create stored procedure to add calendar event
CREATE PROCEDURE AddCalendarEvent(
    IN p_username VARCHAR(50),
    IN p_title VARCHAR(100),
    IN p_description TEXT,
    IN p_event_date DATE,
    IN p_event_time TIME
)
BEGIN
    DECLARE user_id INT;
    
    SELECT id INTO user_id FROM users WHERE username = p_username;
    
    IF user_id IS NOT NULL THEN
        INSERT INTO calendar_events (user_id, title, description, event_date, event_time)
        VALUES (user_id, p_title, p_description, p_event_date, p_event_time);
        SELECT 'Calendar event added successfully' as message;
    ELSE
        SELECT 'User not found' as message;
    END IF;
END //

-- Create stored procedure to get user's calendar events
CREATE PROCEDURE GetUserCalendar(
    IN p_username VARCHAR(50)
)
BEGIN
    DECLARE user_id INT;
    
    SELECT id INTO user_id FROM users WHERE username = p_username;
    
    IF user_id IS NOT NULL THEN
        SELECT title, description, event_date, event_time, created_at
        FROM calendar_events
        WHERE user_id = user_id
        ORDER BY event_date, event_time;
    ELSE
        SELECT 'User not found' as message;
    END IF;
END //

-- Create stored procedure to add note
CREATE PROCEDURE AddNote(
    IN p_username VARCHAR(50),
    IN p_title VARCHAR(100),
    IN p_content TEXT
)
BEGIN
    DECLARE user_id INT;
    
    SELECT id INTO user_id FROM users WHERE username = p_username;
    
    IF user_id IS NOT NULL THEN
        INSERT INTO notes (user_id, title, content)
        VALUES (user_id, p_title, p_content);
        SELECT 'Note added successfully' as message;
    ELSE
        SELECT 'User not found' as message;
    END IF;
END //

-- Create stored procedure to get user's notes
CREATE PROCEDURE GetUserNotes(
    IN p_username VARCHAR(50)
)
BEGIN
    DECLARE user_id INT;
    
    SELECT id INTO user_id FROM users WHERE username = p_username;
    
    IF user_id IS NOT NULL THEN
        SELECT title, content, created_at, updated_at
        FROM notes
        WHERE user_id = user_id
        ORDER BY updated_at DESC;
    ELSE
        SELECT 'User not found' as message;
    END IF;
END //

-- Create stored procedure to save custom data
CREATE PROCEDURE SaveCustomData(
    IN p_username VARCHAR(50),
    IN p_data_type VARCHAR(50),
    IN p_data_value TEXT
)
BEGIN
    DECLARE user_id INT;
    
    SELECT id INTO user_id FROM users WHERE username = p_username;
    
    IF user_id IS NOT NULL THEN
        INSERT INTO custom_data (user_id, data_type, data_value)
        VALUES (user_id, p_data_type, p_data_value)
        ON DUPLICATE KEY UPDATE data_value = p_data_value;
        SELECT 'Custom data saved successfully' as message;
    ELSE
        SELECT 'User not found' as message;
    END IF;
END //

-- Create stored procedure to get user's custom data
CREATE PROCEDURE GetCustomData(
    IN p_username VARCHAR(50),
    IN p_data_type VARCHAR(50)
)
BEGIN
    DECLARE user_id INT;
    
    SELECT id INTO user_id FROM users WHERE username = p_username;
    
    IF user_id IS NOT NULL THEN
        SELECT data_type, data_value, created_at
        FROM custom_data
        WHERE user_id = user_id AND data_type = p_data_type;
    ELSE
        SELECT 'User not found' as message;
    END IF;
END //

DELIMITER ;

-- Example usage:
/*
-- Register a new user
CALL RegisterUser('yu', 'hashed_password_here');

-- Add calendar event for yu
CALL AddCalendarEvent('yu', 'Team Meeting', 'Weekly team sync', '2024-01-20', '14:30:00');

-- Get yu's calendar
CALL GetUserCalendar('yu');

-- Add note for yu
CALL AddNote('yu', 'Project Ideas', 'List of project ideas for 2024');

-- Get yu's notes
CALL GetUserNotes('yu');

-- Save custom data for yu
CALL SaveCustomData('yu', 'todo_list', '["Task 1", "Task 2", "Task 3"]');

-- Get yu's custom data
CALL GetCustomData('yu', 'todo_list');
*/