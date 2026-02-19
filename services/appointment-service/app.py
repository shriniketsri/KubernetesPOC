import os
import logging
from datetime import datetime, timedelta
from flask import Flask, request, jsonify
from flask_cors import CORS
from flask_sqlalchemy import SQLAlchemy
from sqlalchemy import text
from flask_migrate import Migrate
from flask_jwt_extended import JWTManager
from marshmallow import Schema, fields, ValidationError
from prometheus_client import Counter, Histogram, generate_latest, CONTENT_TYPE_LATEST
import requests
from dotenv import load_dotenv

load_dotenv()

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

app = Flask(__name__)

# Construct database URI from individual environment variables
db_username = os.getenv('POSTGRES_USERNAME', 'postgres')
db_password = os.getenv('POSTGRES_PASSWORD', 'password')
db_host = os.getenv('POSTGRES_HOST', 'postgres')
db_port = os.getenv('POSTGRES_PORT', '5432')
db_name = os.getenv('POSTGRES_DB', 'appointment_db')

app.config['SQLALCHEMY_DATABASE_URI'] = f'postgresql://{db_username}:{db_password}@{db_host}:{db_port}/{db_name}'
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
app.config['JWT_SECRET_KEY'] = os.getenv('JWT_SECRET_KEY', 'your-secret-key')

db = SQLAlchemy(app)
migrate = Migrate(app, db)
jwt = JWTManager(app)
CORS(app)

# Prometheus metrics
REQUEST_COUNT = Counter('appointment_requests_total', 'Total appointment requests', ['method', 'endpoint'])
REQUEST_DURATION = Histogram('appointment_request_duration_seconds', 'Appointment request duration')

# Models
class Appointment(db.Model):
    __tablename__ = 'appointments'
    
    id = db.Column(db.Integer, primary_key=True)
    patient_id = db.Column(db.String(50), nullable=False, index=True)
    doctor_id = db.Column(db.String(50), nullable=False)
    appointment_date = db.Column(db.DateTime, nullable=False, index=True)
    duration_minutes = db.Column(db.Integer, default=30)
    appointment_type = db.Column(db.String(50), nullable=False)
    status = db.Column(db.String(20), default='scheduled')  # scheduled, confirmed, completed, cancelled
    notes = db.Column(db.Text)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    def to_dict(self):
        return {
            'id': self.id,
            'patient_id': self.patient_id,
            'doctor_id': self.doctor_id,
            'appointment_date': self.appointment_date.isoformat(),
            'duration_minutes': self.duration_minutes,
            'appointment_type': self.appointment_type,
            'status': self.status,
            'notes': self.notes,
            'created_at': self.created_at.isoformat(),
            'updated_at': self.updated_at.isoformat()
        }

# Schemas
class AppointmentSchema(Schema):
    id = fields.Integer(dump_only=True)
    patient_id = fields.String(required=True)
    doctor_id = fields.String(required=True)
    appointment_date = fields.DateTime(required=True)
    duration_minutes = fields.Integer(missing=30)
    appointment_type = fields.String(required=True)
    status = fields.String(missing='scheduled')
    notes = fields.String(allow_none=True)

appointment_schema = AppointmentSchema()
appointments_schema = AppointmentSchema(many=True)

# Middleware for metrics
@app.before_request
def before_request():
    REQUEST_COUNT.labels(method=request.method, endpoint=request.endpoint).inc()

@app.after_request
def after_request(response):
    return response

# Root endpoint
@app.route('/')
def root():
    return jsonify({
        'service': 'Appointment Service',
        'version': '1.0.0',
        'description': 'Healthcare appointment management microservice',
        'endpoints': {
            'health': '/health',
            'readiness': '/ready',
            'metrics': '/metrics',
            'appointments': {
                'list': 'GET /api/appointments',
                'create': 'POST /api/appointments',
                'get': 'GET /api/appointments/{id}',
                'update': 'PUT /api/appointments/{id}',
                'delete': 'DELETE /api/appointments/{id}'
            },
            'availability': 'GET /api/availability/{doctor_id}'
        },
        'timestamp': datetime.utcnow().isoformat()
    })

# Health check endpoints
@app.route('/health')
def health():
    return jsonify({
        'status': 'healthy',
        'service': 'appointment-service',
        'timestamp': datetime.utcnow().isoformat(),
        'version': '1.0.0'
    })

@app.route('/ready')
def ready():
    try:
        # Test database connection
        db.session.execute(text('SELECT 1'))
        return jsonify({
            'status': 'ready',
            'database': 'connected'
        })
    except Exception as e:
        logger.error(f"Readiness check failed: {e}")
        return jsonify({
            'status': 'not ready',
            'database': 'disconnected',
            'error': str(e)
        }), 503

# Metrics endpoint
@app.route('/metrics')
def metrics():
    return generate_latest(), 200, {'Content-Type': CONTENT_TYPE_LATEST}

# Helper function to validate patient exists
def validate_patient(patient_id):
    try:
        patient_service_url = os.getenv('PATIENT_SERVICE_URL', 'http://patient-service:3001')
        response = requests.get(f"{patient_service_url}/api/patients/{patient_id}", timeout=5)
        return response.status_code == 200
    except requests.RequestException as e:
        logger.error(f"Failed to validate patient {patient_id}: {e}")
        return False

# Appointment routes
@app.route('/api/appointments', methods=['GET'])
def get_appointments():
    try:
        page = request.args.get('page', 1, type=int)
        per_page = request.args.get('per_page', 10, type=int)
        patient_id = request.args.get('patient_id')
        doctor_id = request.args.get('doctor_id')
        status = request.args.get('status')
        date_from = request.args.get('date_from')
        date_to = request.args.get('date_to')
        
        query = Appointment.query
        
        if patient_id:
            query = query.filter_by(patient_id=patient_id)
        if doctor_id:
            query = query.filter_by(doctor_id=doctor_id)
        if status:
            query = query.filter_by(status=status)
        if date_from:
            query = query.filter(Appointment.appointment_date >= datetime.fromisoformat(date_from))
        if date_to:
            query = query.filter(Appointment.appointment_date <= datetime.fromisoformat(date_to))
        
        appointments = query.paginate(
            page=page, 
            per_page=per_page, 
            error_out=False
        )
        
        return jsonify({
            'appointments': [apt.to_dict() for apt in appointments.items],
            'total': appointments.total,
            'pages': appointments.pages,
            'current_page': page,
            'has_next': appointments.has_next,
            'has_prev': appointments.has_prev
        })
        
    except Exception as e:
        logger.error(f"Error getting appointments: {e}")
        return jsonify({'error': 'Internal server error'}), 500

@app.route('/api/appointments/<int:appointment_id>', methods=['GET'])
def get_appointment(appointment_id):
    try:
        appointment = Appointment.query.get_or_404(appointment_id)
        return jsonify(appointment.to_dict())
    except Exception as e:
        logger.error(f"Error getting appointment {appointment_id}: {e}")
        return jsonify({'error': 'Appointment not found'}), 404

@app.route('/api/appointments', methods=['POST'])
def create_appointment():
    try:
        data = request.get_json()
        
        # Validate input
        try:
            result = appointment_schema.load(data)
        except ValidationError as err:
            return jsonify({'error': 'Validation error', 'messages': err.messages}), 400
        
        # Validate patient exists
        if not validate_patient(result['patient_id']):
            return jsonify({'error': 'Patient not found'}), 400
        
        # Check for scheduling conflicts
        appointment_start = result['appointment_date']
        appointment_end = appointment_start + timedelta(minutes=result.get('duration_minutes', 30))
        
        conflict = Appointment.query.filter(
            Appointment.doctor_id == result['doctor_id'],
            Appointment.appointment_date < appointment_end,
            Appointment.appointment_date + timedelta(minutes=Appointment.duration_minutes) > appointment_start,
            Appointment.status.in_(['scheduled', 'confirmed'])
        ).first()
        
        if conflict:
            return jsonify({'error': 'Scheduling conflict detected'}), 409
        
        appointment = Appointment(**result)
        db.session.add(appointment)
        db.session.commit()
        
        logger.info(f"Appointment created: {appointment.id}")
        return jsonify(appointment.to_dict()), 201
        
    except Exception as e:
        logger.error(f"Error creating appointment: {e}")
        db.session.rollback()
        return jsonify({'error': 'Internal server error'}), 500

@app.route('/api/appointments/<int:appointment_id>', methods=['PUT'])
def update_appointment(appointment_id):
    try:
        appointment = Appointment.query.get_or_404(appointment_id)
        data = request.get_json()
        
        # Validate input
        try:
            result = appointment_schema.load(data, partial=True)
        except ValidationError as err:
            return jsonify({'error': 'Validation error', 'messages': err.messages}), 400
        
        # Update appointment
        for key, value in result.items():
            setattr(appointment, key, value)
        
        appointment.updated_at = datetime.utcnow()
        db.session.commit()
        
        logger.info(f"Appointment updated: {appointment.id}")
        return jsonify(appointment.to_dict())
        
    except Exception as e:
        logger.error(f"Error updating appointment {appointment_id}: {e}")
        db.session.rollback()
        return jsonify({'error': 'Internal server error'}), 500

@app.route('/api/appointments/<int:appointment_id>', methods=['DELETE'])
def cancel_appointment(appointment_id):
    try:
        appointment = Appointment.query.get_or_404(appointment_id)
        appointment.status = 'cancelled'
        appointment.updated_at = datetime.utcnow()
        db.session.commit()
        
        logger.info(f"Appointment cancelled: {appointment.id}")
        return '', 204
        
    except Exception as e:
        logger.error(f"Error cancelling appointment {appointment_id}: {e}")
        db.session.rollback()
        return jsonify({'error': 'Internal server error'}), 500

# Availability check endpoint
@app.route('/api/availability/<doctor_id>', methods=['GET'])
def check_availability(doctor_id):
    try:
        date_str = request.args.get('date')
        if not date_str:
            return jsonify({'error': 'Date parameter required'}), 400
        
        date = datetime.fromisoformat(date_str).date()
        start_of_day = datetime.combine(date, datetime.min.time())
        end_of_day = datetime.combine(date, datetime.max.time())
        
        appointments = Appointment.query.filter(
            Appointment.doctor_id == doctor_id,
            Appointment.appointment_date >= start_of_day,
            Appointment.appointment_date <= end_of_day,
            Appointment.status.in_(['scheduled', 'confirmed'])
        ).all()
        
        # Generate available slots (9 AM to 5 PM, 30-minute slots)
        available_slots = []
        current_time = start_of_day.replace(hour=9)
        end_time = start_of_day.replace(hour=17)
        
        while current_time < end_time:
            slot_end = current_time + timedelta(minutes=30)
            
            # Check if slot conflicts with existing appointments
            conflict = any(
                apt.appointment_date < slot_end and
                apt.appointment_date + timedelta(minutes=apt.duration_minutes) > current_time
                for apt in appointments
            )
            
            if not conflict:
                available_slots.append(current_time.isoformat())
            
            current_time = slot_end
        
        return jsonify({
            'doctor_id': doctor_id,
            'date': date_str,
            'available_slots': available_slots
        })
        
    except Exception as e:
        logger.error(f"Error checking availability for doctor {doctor_id}: {e}")
        return jsonify({'error': 'Internal server error'}), 500

# Error handlers
@app.errorhandler(404)
def not_found(error):
    return jsonify({'error': 'Resource not found'}), 404

@app.errorhandler(500)
def internal_error(error):
    db.session.rollback()
    return jsonify({'error': 'Internal server error'}), 500

if __name__ == '__main__':
    with app.app_context():
        db.create_all()
    app.run(host='0.0.0.0', port=int(os.getenv('PORT', 3002)), debug=os.getenv('DEBUG', 'False').lower() == 'true')