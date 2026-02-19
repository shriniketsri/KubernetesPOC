package main

import (
	"context"
	"net/http"
	"os"
	"os/signal"
	"strconv"
	"syscall"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/go-playground/validator/v10"
	"github.com/joho/godotenv"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"
	"github.com/sirupsen/logrus"
	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/bson/primitive"
	"go.mongodb.org/mongo-driver/mongo"
	"go.mongodb.org/mongo-driver/mongo/options"
)

var (
	db                *mongo.Database
	logger            *logrus.Logger
	validate          *validator.Validate
	requestCounter    *prometheus.CounterVec
	requestDuration   *prometheus.HistogramVec
)

type MedicalRecord struct {
	ID               primitive.ObjectID `bson:"_id,omitempty" json:"id,omitempty"`
	PatientID        string             `bson:"patient_id" json:"patient_id" validate:"required"`
	DoctorID         string             `bson:"doctor_id" json:"doctor_id" validate:"required"`
	AppointmentID    string             `bson:"appointment_id" json:"appointment_id"`
	RecordType       string             `bson:"record_type" json:"record_type" validate:"required,oneof=consultation diagnosis prescription lab_result imaging"`
	Title            string             `bson:"title" json:"title" validate:"required"`
	Description      string             `bson:"description" json:"description"`
	Diagnosis        []Diagnosis        `bson:"diagnosis" json:"diagnosis"`
	Prescriptions    []Prescription     `bson:"prescriptions" json:"prescriptions"`
	LabResults       []LabResult        `bson:"lab_results" json:"lab_results"`
	VitalSigns       *VitalSigns        `bson:"vital_signs" json:"vital_signs"`
	Attachments      []Attachment       `bson:"attachments" json:"attachments"`
	IsConfidential   bool               `bson:"is_confidential" json:"is_confidential"`
	CreatedAt        time.Time          `bson:"created_at" json:"created_at"`
	UpdatedAt        time.Time          `bson:"updated_at" json:"updated_at"`
	CreatedBy        string             `bson:"created_by" json:"created_by"`
	LastModifiedBy   string             `bson:"last_modified_by" json:"last_modified_by"`
}

type Diagnosis struct {
	Code        string    `bson:"code" json:"code" validate:"required"`
	Description string    `bson:"description" json:"description" validate:"required"`
	Severity    string    `bson:"severity" json:"severity" validate:"oneof=mild moderate severe critical"`
	Status      string    `bson:"status" json:"status" validate:"oneof=active resolved chronic"`
	DateDiagnosed time.Time `bson:"date_diagnosed" json:"date_diagnosed"`
}

type Prescription struct {
	MedicationName string    `bson:"medication_name" json:"medication_name" validate:"required"`
	Dosage         string    `bson:"dosage" json:"dosage" validate:"required"`
	Frequency      string    `bson:"frequency" json:"frequency" validate:"required"`
	Duration       string    `bson:"duration" json:"duration"`
	Instructions   string    `bson:"instructions" json:"instructions"`
	PrescribedDate time.Time `bson:"prescribed_date" json:"prescribed_date"`
	StartDate      time.Time `bson:"start_date" json:"start_date"`
	EndDate        time.Time `bson:"end_date" json:"end_date"`
}

type LabResult struct {
	TestName     string    `bson:"test_name" json:"test_name" validate:"required"`
	TestCode     string    `bson:"test_code" json:"test_code"`
	Result       string    `bson:"result" json:"result" validate:"required"`
	Unit         string    `bson:"unit" json:"unit"`
	ReferenceRange string  `bson:"reference_range" json:"reference_range"`
	Status       string    `bson:"status" json:"status" validate:"oneof=normal abnormal critical"`
	TestDate     time.Time `bson:"test_date" json:"test_date"`
	LabName      string    `bson:"lab_name" json:"lab_name"`
}

type VitalSigns struct {
	BloodPressureSystolic  int       `bson:"blood_pressure_systolic" json:"blood_pressure_systolic"`
	BloodPressureDiastolic int       `bson:"blood_pressure_diastolic" json:"blood_pressure_diastolic"`
	HeartRate              int       `bson:"heart_rate" json:"heart_rate"`
	Temperature            float64   `bson:"temperature" json:"temperature"`
	RespiratoryRate        int       `bson:"respiratory_rate" json:"respiratory_rate"`
	OxygenSaturation       int       `bson:"oxygen_saturation" json:"oxygen_saturation"`
	Weight                 float64   `bson:"weight" json:"weight"`
	Height                 float64   `bson:"height" json:"height"`
	BMI                    float64   `bson:"bmi" json:"bmi"`
	MeasuredAt             time.Time `bson:"measured_at" json:"measured_at"`
}

type Attachment struct {
	FileName    string    `bson:"file_name" json:"file_name" validate:"required"`
	FileType    string    `bson:"file_type" json:"file_type" validate:"required"`
	FileSize    int64     `bson:"file_size" json:"file_size"`
	StoragePath string    `bson:"storage_path" json:"storage_path"`
	UploadedAt  time.Time `bson:"uploaded_at" json:"uploaded_at"`
	Description string    `bson:"description" json:"description"`
}

func init() {
	// Load environment variables
	godotenv.Load()

	// Initialize logger
	logger = logrus.New()
	logger.SetFormatter(&logrus.JSONFormatter{})
	logger.SetLevel(logrus.InfoLevel)

	// Initialize validator
	validate = validator.New()

	// Initialize Prometheus metrics
	requestCounter = prometheus.NewCounterVec(
		prometheus.CounterOpts{
			Name: "medical_records_requests_total",
			Help: "Total number of requests to medical records service",
		},
		[]string{"method", "endpoint", "status"},
	)

	requestDuration = prometheus.NewHistogramVec(
		prometheus.HistogramOpts{
			Name: "medical_records_request_duration_seconds",
			Help: "Duration of requests to medical records service",
		},
		[]string{"method", "endpoint"},
	)

	prometheus.MustRegister(requestCounter, requestDuration)
}

func connectMongoDB() *mongo.Client {
	// Construct MongoDB URI from environment variables
	mongoHost := os.Getenv("MONGO_HOST")
	if mongoHost == "" {
		mongoHost = "mongo"
	}
	
	mongoPort := os.Getenv("MONGO_PORT")
	if mongoPort == "" {
		mongoPort = "27017"
	}
	
	mongoDatabase := os.Getenv("MONGO_DATABASE")
	if mongoDatabase == "" {
		mongoDatabase = "medical_records_db"
	}
	
	mongoUsername := os.Getenv("MONGO_USERNAME")
	mongoPassword := os.Getenv("MONGO_PASSWORD")
	
	var mongoURI string
	if mongoUsername != "" && mongoPassword != "" {
		mongoURI = "mongodb://" + mongoUsername + ":" + mongoPassword + "@" + mongoHost + ":" + mongoPort + "/" + mongoDatabase + "?authSource=admin"
	} else {
		mongoURI = "mongodb://" + mongoHost + ":" + mongoPort + "/" + mongoDatabase
	}

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	client, err := mongo.Connect(ctx, options.Client().ApplyURI(mongoURI))
	if err != nil {
		logger.Fatalf("Failed to connect to MongoDB: %v", err)
	}

	// Ping the database
	if err := client.Ping(ctx, nil); err != nil {
		logger.Fatalf("Failed to ping MongoDB: %v", err)
	}

	logger.Info("Connected to MongoDB successfully")
	return client
}

func prometheusMiddleware() gin.HandlerFunc {
	return gin.HandlerFunc(func(c *gin.Context) {
		start := time.Now()

		c.Next()

		duration := time.Since(start)
		status := strconv.Itoa(c.Writer.Status())

		requestCounter.WithLabelValues(c.Request.Method, c.FullPath(), status).Inc()
		requestDuration.WithLabelValues(c.Request.Method, c.FullPath()).Observe(duration.Seconds())
	})
}

func loggingMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		start := time.Now()
		path := c.Request.URL.Path
		raw := c.Request.URL.RawQuery

		c.Next()

		latency := time.Since(start)
		clientIP := c.ClientIP()
		method := c.Request.Method
		statusCode := c.Writer.Status()

		if raw != "" {
			path = path + "?" + raw
		}

		logger.WithFields(logrus.Fields{
			"status_code": statusCode,
			"latency":     latency,
			"client_ip":   clientIP,
			"method":      method,
			"path":        path,
		}).Info("Request processed")
	}
}

func rootHandler(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{
		"service":     "Medical Records Service",
		"version":     "1.0.0",
		"description": "Healthcare medical records management microservice",
		"endpoints": gin.H{
			"health":     "/health",
			"readiness":  "/ready",
			"metrics":    "/metrics",
			"records": gin.H{
				"list":   "GET /api/medical-records",
				"create": "POST /api/medical-records",
				"get":    "GET /api/medical-records/{id}",
				"update": "PUT /api/medical-records/{id}",
				"delete": "DELETE /api/medical-records/{id}",
			},
		},
		"timestamp": time.Now().Format(time.RFC3339),
	})
}

func healthHandler(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{
		"status":    "healthy",
		"service":   "medical-records-service",
		"timestamp": time.Now().Format(time.RFC3339),
		"version":   "1.0.0",
	})
}

func readinessHandler(c *gin.Context) {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	// Test database connection
	if err := db.Client().Ping(ctx, nil); err != nil {
		logger.WithError(err).Error("Database ping failed")
		c.JSON(http.StatusServiceUnavailable, gin.H{
			"status":   "not ready",
			"database": "disconnected",
			"error":    err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"status":   "ready",
		"database": "connected",
	})
}

func metricsHandler() gin.HandlerFunc {
	h := promhttp.Handler()
	return func(c *gin.Context) {
		h.ServeHTTP(c.Writer, c.Request)
	}
}

func getMedicalRecords(c *gin.Context) {
	patientID := c.Query("patient_id")
	recordType := c.Query("record_type")
	page := c.DefaultQuery("page", "1")
	limit := c.DefaultQuery("limit", "10")

	pageNum, _ := strconv.Atoi(page)
	limitNum, _ := strconv.Atoi(limit)
	skip := (pageNum - 1) * limitNum

	filter := bson.M{}
	if patientID != "" {
		filter["patient_id"] = patientID
	}
	if recordType != "" {
		filter["record_type"] = recordType
	}

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	// Get total count
	total, err := db.Collection("medical_records").CountDocuments(ctx, filter)
	if err != nil {
		logger.WithError(err).Error("Failed to count medical records")
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to count records"})
		return
	}

	// Get records with pagination
	options := options.Find().
		SetSort(bson.D{{Key: "created_at", Value: -1}}).
		SetSkip(int64(skip)).
		SetLimit(int64(limitNum))

	cursor, err := db.Collection("medical_records").Find(ctx, filter, options)
	if err != nil {
		logger.WithError(err).Error("Failed to fetch medical records")
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch records"})
		return
	}
	defer cursor.Close(ctx)

	var records []MedicalRecord
	if err := cursor.All(ctx, &records); err != nil {
		logger.WithError(err).Error("Failed to decode medical records")
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to decode records"})
		return
	}

	totalPages := (int(total) + limitNum - 1) / limitNum

	c.JSON(http.StatusOK, gin.H{
		"records":      records,
		"total":        total,
		"page":         pageNum,
		"limit":        limitNum,
		"total_pages":  totalPages,
		"has_next":     pageNum < totalPages,
		"has_previous": pageNum > 1,
	})
}

func getMedicalRecord(c *gin.Context) {
	id := c.Param("id")
	objectID, err := primitive.ObjectIDFromHex(id)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid record ID"})
		return
	}

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	var record MedicalRecord
	err = db.Collection("medical_records").FindOne(ctx, bson.M{"_id": objectID}).Decode(&record)
	if err != nil {
		if err == mongo.ErrNoDocuments {
			c.JSON(http.StatusNotFound, gin.H{"error": "Medical record not found"})
			return
		}
		logger.WithError(err).Error("Failed to fetch medical record")
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch record"})
		return
	}

	c.JSON(http.StatusOK, record)
}

func createMedicalRecord(c *gin.Context) {
	var record MedicalRecord
	if err := c.ShouldBindJSON(&record); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	if err := validate.Struct(&record); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	record.ID = primitive.NewObjectID()
	record.CreatedAt = time.Now()
	record.UpdatedAt = time.Now()

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	_, err := db.Collection("medical_records").InsertOne(ctx, record)
	if err != nil {
		logger.WithError(err).Error("Failed to create medical record")
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create record"})
		return
	}

	logger.WithField("record_id", record.ID.Hex()).Info("Medical record created successfully")
	c.JSON(http.StatusCreated, record)
}

func updateMedicalRecord(c *gin.Context) {
	id := c.Param("id")
	objectID, err := primitive.ObjectIDFromHex(id)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid record ID"})
		return
	}

	var updateData MedicalRecord
	if err := c.ShouldBindJSON(&updateData); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	updateData.UpdatedAt = time.Now()

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	update := bson.M{"$set": updateData}
	result, err := db.Collection("medical_records").UpdateOne(ctx, bson.M{"_id": objectID}, update)
	if err != nil {
		logger.WithError(err).Error("Failed to update medical record")
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update record"})
		return
	}

	if result.MatchedCount == 0 {
		c.JSON(http.StatusNotFound, gin.H{"error": "Medical record not found"})
		return
	}

	logger.WithField("record_id", id).Info("Medical record updated successfully")

	// Fetch and return the updated record
	var updatedRecord MedicalRecord
	err = db.Collection("medical_records").FindOne(ctx, bson.M{"_id": objectID}).Decode(&updatedRecord)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch updated record"})
		return
	}

	c.JSON(http.StatusOK, updatedRecord)
}

func deleteMedicalRecord(c *gin.Context) {
	id := c.Param("id")
	objectID, err := primitive.ObjectIDFromHex(id)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid record ID"})
		return
	}

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	result, err := db.Collection("medical_records").DeleteOne(ctx, bson.M{"_id": objectID})
	if err != nil {
		logger.WithError(err).Error("Failed to delete medical record")
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to delete record"})
		return
	}

	if result.DeletedCount == 0 {
		c.JSON(http.StatusNotFound, gin.H{"error": "Medical record not found"})
		return
	}

	logger.WithField("record_id", id).Info("Medical record deleted successfully")
	c.Status(http.StatusNoContent)
}

func getPatientSummary(c *gin.Context) {
	patientID := c.Param("patient_id")
	if patientID == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Patient ID is required"})
		return
	}

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	// Aggregation pipeline to get patient summary
	pipeline := []bson.M{
		{"$match": bson.M{"patient_id": patientID}},
		{"$group": bson.M{
			"_id": "$patient_id",
			"total_records": bson.M{"$sum": 1},
			"record_types": bson.M{"$addToSet": "$record_type"},
			"latest_record": bson.M{"$max": "$created_at"},
			"total_diagnoses": bson.M{"$sum": bson.M{"$size": bson.M{"$ifNull": []interface{}{"$diagnosis", []interface{}{}}}}},
			"total_prescriptions": bson.M{"$sum": bson.M{"$size": bson.M{"$ifNull": []interface{}{"$prescriptions", []interface{}{}}}}},
			"total_lab_results": bson.M{"$sum": bson.M{"$size": bson.M{"$ifNull": []interface{}{"$lab_results", []interface{}{}}}}},
		}},
	}

	cursor, err := db.Collection("medical_records").Aggregate(ctx, pipeline)
	if err != nil {
		logger.WithError(err).Error("Failed to aggregate patient summary")
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to generate summary"})
		return
	}
	defer cursor.Close(ctx)

	var summaries []bson.M
	if err := cursor.All(ctx, &summaries); err != nil {
		logger.WithError(err).Error("Failed to decode patient summary")
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to decode summary"})
		return
	}

	if len(summaries) == 0 {
		c.JSON(http.StatusNotFound, gin.H{"error": "No records found for patient"})
		return
	}

	c.JSON(http.StatusOK, summaries[0])
}

func setupRouter() *gin.Engine {
	// Set Gin to release mode in production
	if os.Getenv("GIN_MODE") != "debug" {
		gin.SetMode(gin.ReleaseMode)
	}

	router := gin.New()

	// Middleware
	router.Use(gin.Recovery())
	router.Use(loggingMiddleware())
	router.Use(prometheusMiddleware())

	// Root endpoint
	router.GET("/", rootHandler)

	// Health and monitoring endpoints
	router.GET("/health", healthHandler)
	router.GET("/ready", readinessHandler)
	router.GET("/metrics", metricsHandler())

	// API routes
	api := router.Group("/api")
	{
		api.GET("/medical-records", getMedicalRecords)
		api.GET("/medical-records/:id", getMedicalRecord)
		api.POST("/medical-records", createMedicalRecord)
		api.PUT("/medical-records/:id", updateMedicalRecord)
		api.DELETE("/medical-records/:id", deleteMedicalRecord)
		api.GET("/patients/:patient_id/summary", getPatientSummary)
	}

	return router
}

func main() {
	// Connect to MongoDB
	client := connectMongoDB()
	dbName := os.Getenv("DB_NAME")
	if dbName == "" {
		dbName = "medical_records_db"
	}
	db = client.Database(dbName)

	// Setup router
	router := setupRouter()

	// Server configuration
	port := os.Getenv("PORT")
	if port == "" {
		port = "3003"
	}

	server := &http.Server{
		Addr:         ":" + port,
		Handler:      router,
		ReadTimeout:  30 * time.Second,
		WriteTimeout: 30 * time.Second,
	}

	// Graceful shutdown
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)

	go func() {
		logger.WithField("port", port).Info("Starting medical records service")
		if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			logger.WithError(err).Fatal("Failed to start server")
		}
	}()

	<-quit
	logger.Info("Shutting down server...")

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	if err := server.Shutdown(ctx); err != nil {
		logger.WithError(err).Fatal("Server forced to shutdown")
	}

	// Close MongoDB connection
	if err := client.Disconnect(ctx); err != nil {
		logger.WithError(err).Error("Failed to disconnect from MongoDB")
	}

	logger.Info("Server exited")
}