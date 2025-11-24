/**
 * Employee Management Application
 * Frontend JavaScript for API interaction
 */

const API_BASE = '/api';

// Utility functions
const showNotification = (message, type = 'success') => {
    const notification = document.createElement('div');
    notification.className = `notification ${type}`;
    notification.textContent = message;
    document.body.appendChild(notification);
    
    setTimeout(() => {
        notification.style.animation = 'slideInRight 0.4s ease reverse';
        setTimeout(() => notification.remove(), 400);
    }, 3000);
};

const formatDate = (dateString) => {
    const date = new Date(dateString);
    const now = new Date();
    const diffMs = now - date;
    const diffMins = Math.floor(diffMs / 60000);
    const diffHours = Math.floor(diffMs / 3600000);
    const diffDays = Math.floor(diffMs / 86400000);
    
    if (diffMins < 1) return 'Just now';
    if (diffMins < 60) return `${diffMins} minute${diffMins > 1 ? 's' : ''} ago`;
    if (diffHours < 24) return `${diffHours} hour${diffHours > 1 ? 's' : ''} ago`;
    if (diffDays < 7) return `${diffDays} day${diffDays > 1 ? 's' : ''} ago`;
    
    return date.toLocaleDateString('en-US', { 
        year: 'numeric', 
        month: 'short', 
        day: 'numeric' 
    });
};

// API functions
const fetchEmployees = async () => {
    try {
        const response = await fetch(`${API_BASE}/employees`);
        if (!response.ok) throw new Error('Failed to fetch employees');
        const data = await response.json();
        return data.employees;
    } catch (error) {
        console.error('Error fetching employees:', error);
        showNotification('Failed to load employees', 'error');
        return [];
    }
};

const addEmployee = async (name, email) => {
    try {
        const response = await fetch(`${API_BASE}/employees`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({ name, email }),
        });
        
        if (!response.ok) {
            const error = await response.json();
            throw new Error(error.detail || 'Failed to add employee');
        }
        
        const data = await response.json();
        return data;
    } catch (error) {
        console.error('Error adding employee:', error);
        throw error;
    }
};

const deleteEmployee = async (email) => {
    try {
        const response = await fetch(`${API_BASE}/employees/${encodeURIComponent(email)}`, {
            method: 'DELETE',
        });
        
        if (!response.ok) {
            const error = await response.json();
            throw new Error(error.detail || 'Failed to delete employee');
        }
        
        return await response.json();
    } catch (error) {
        console.error('Error deleting employee:', error);
        throw error;
    }
};

// UI rendering functions
const renderEmployeeList = (employees) => {
    const listContainer = document.getElementById('employeeList');
    
    if (employees.length === 0) {
        listContainer.innerHTML = `
            <div class="empty-state">
                <div class="empty-state-icon">📭</div>
                <p>No employees yet. Add your first employee above!</p>
            </div>
        `;
        return;
    }
    
    listContainer.innerHTML = employees.map((employee, index) => `
        <div class="employee-item" style="animation-delay: ${index * 0.05}s">
            <div class="employee-info">
                <div class="employee-name">${escapeHtml(employee.name)}</div>
                <div class="employee-email">${escapeHtml(employee.email)}</div>
                <div class="employee-date">Added ${formatDate(employee.created_at)}</div>
            </div>
            <button 
                class="btn btn-danger" 
                onclick="handleDelete('${escapeHtml(employee.email)}')"
                aria-label="Delete ${escapeHtml(employee.name)}"
            >
                Delete
            </button>
        </div>
    `).join('');
};

const escapeHtml = (text) => {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
};

// Event handlers
const handleSubmit = async (e) => {
    e.preventDefault();
    
    const form = e.target;
    const name = form.name.value.trim();
    const email = form.email.value.trim();
    
    if (!name || !email) {
        showNotification('Please fill in all fields', 'error');
        return;
    }
    
    // Show loading state
    const submitBtn = document.getElementById('submitBtn');
    const btnText = document.getElementById('btnText');
    const btnLoading = document.getElementById('btnLoading');
    
    submitBtn.disabled = true;
    btnText.style.display = 'none';
    btnLoading.style.display = 'inline-block';
    
    try {
        const result = await addEmployee(name, email);
        showNotification(result.message, 'success');
        form.reset();
        await loadEmployees();
    } catch (error) {
        showNotification(error.message, 'error');
    } finally {
        submitBtn.disabled = false;
        btnText.style.display = 'inline';
        btnLoading.style.display = 'none';
    }
};

const handleDelete = async (email) => {
    if (!confirm(`Are you sure you want to delete ${email}?`)) {
        return;
    }
    
    try {
        const result = await deleteEmployee(email);
        showNotification(result.message, 'success');
        await loadEmployees();
    } catch (error) {
        showNotification(error.message, 'error');
    }
};

// Make handleDelete available globally for onclick handlers
window.handleDelete = handleDelete;

// Load employees
const loadEmployees = async () => {
    const employees = await fetchEmployees();
    renderEmployeeList(employees);
};

// Initialize app
document.addEventListener('DOMContentLoaded', () => {
    // Set up form submission
    const form = document.getElementById('employeeForm');
    form.addEventListener('submit', handleSubmit);
    
    // Load initial data
    loadEmployees();
    
    // Refresh every 30 seconds
    setInterval(loadEmployees, 30000);
});
