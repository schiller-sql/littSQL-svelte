-- UTILS --
DROP SCHEMA IF EXISTS utils CASCADE;
CREATE SCHEMA utils;

CREATE OR REPLACE FUNCTION utils.random_string(length INTEGER) RETURNS CHAR AS
$$
DECLARE
    chars  TEXT[] := '{0,1,2,3,4,5,6,7,8,9,A,B,C,D,E,F,G,H,I,J,K,L,M,N,O,P,Q,R,S,T,U,V,W,X,Y,Z}';
    result TEXT   := '';
BEGIN
    IF length <= 0 THEN
        RAISE EXCEPTION 'Given length cannot be less than 0';
    END IF;
    FOR i IN 1..length
        LOOP
            result := result || chars[1 + RANDOM() * (ARRAY_LENGTH(chars, 1) - 1)];
        END LOOP;
    RETURN result;
END;
$$ LANGUAGE plpgsql;


DROP SCHEMA IF EXISTS public CASCADE;
CREATE SCHEMA public;
-- TEACHER SIDE --
CREATE TABLE teachers -- represents a teacher
(
    id       INTEGER PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    email    VARCHAR UNIQUE NOT NULL,
    password VARCHAR        NOT NULL
);

CREATE TABLE database_templates -- represents a sample database that can be used in a project
(
    id          INTEGER PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    name        VARCHAR NOT NULL,
    description TEXT    NOT NULL,
    sql         TEXT    NOT NULL
);

-- TODO: add support for PDF, for example through attributes: documentation bytea, documentation_type (md/pdf)
CREATE TABLE projects -- represents a template for a project a teacher can use as an assignment
(
    id               INTEGER PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    name             VARCHAR NOT NULL,
    documentation_md TEXT    NOT NULL DEFAULT '',
    db_sql           TEXT,
    owner_id         INTEGER REFERENCES teachers
);

-- TODO: possibly also cache the md as html (would conflict with todo in like 41 however
CREATE TABLE cached_projects_sql_data
(
    project_id INTEGER PRIMARY KEY REFERENCES projects,
    data       bytea NOT NULL
);

CREATE TABLE tasks -- a group of questions, can be voluntary or not
(
    project_id   INTEGER  NOT NULL REFERENCES projects ON DELETE CASCADE,
    number       SMALLINT NOT NULL CHECK ( number >= 0 ), -- position of the task (#1, #2, etc.)
    description  TEXT     NOT NULL,
    is_voluntary bool     NOT NULL DEFAULT FALSE,
    PRIMARY KEY (project_id, number)
);

CREATE TYPE question_type AS ENUM ( -- type of question
--    'multiple_choice',
--    'true/false',
--    'sql-without-question', -- a sql question but as a question you get a query output that you have to come to
    'sql',
    'text'
    );

CREATE TABLE questions -- a question asked to the participant, is part of a task and contains the solution
(
    project_id  INTEGER       NOT NULL REFERENCES projects ON DELETE CASCADE,
    task_number INTEGER       NOT NULL,
    question    VARCHAR       NOT NULL,
    number      SMALLINT      NOT NULL CHECK ( number >= 0 ),
    type        question_type NOT NULL,
    solution    VARCHAR       NOT NULL,
    PRIMARY KEY (project_id, task_number, number),
    FOREIGN KEY (project_id, task_number) REFERENCES tasks (project_id, number) ON DELETE CASCADE
);

-- STUDENT SIDE --
-- TODO: more than one teacher for the same course
CREATE TABLE courses -- a course with participants, belongs to a teacher
(
    id         INTEGER PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    teacher_id INTEGER NOT NULL REFERENCES teachers ON DELETE CASCADE,
    name       VARCHAR NOT NULL CHECK ( LENGTH(name) > 2 )
);

-- TODO: allow participants to join multiple courses
-- TODO: link/QR-code for joinig
CREATE TABLE participants -- a participant of a course, a participant can't be in multiple courses (by now)
(
    id          INTEGER PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    course_id   INTEGER        NOT NULL REFERENCES courses ON DELETE CASCADE,
    name        VARCHAR,
    access_code CHAR(6) UNIQUE NOT NULL DEFAULT (utils.random_string(6))
);

CREATE TYPE assignment_status AS ENUM ( -- the status of one assignment of a course
    'finished',
    'open',
    'locked'
    );

CREATE TYPE assignment_solution_mode AS ENUM ( -- how the solutions should be shown to the participant
    'exam', -- no solutions, no query output, no submitting
    'tryout', -- on sql questions can see if the query wrong/the supposed query output is shown,
    -- after submitting, the solutions are shown, however the query can't be resubmitted
    'no-solutions-tryout', -- same as tryout, but after submitting the solutions are still not shown
    'voluntary' -- can always see if requested, no submitting
    );

-- TODO: timer for assignment (submission date)
-- TODO: be possible to have the same project as multiple assigments
-- TODO: assignment comment (and custom title?), from the teacher (for example: You have to do this)
CREATE TABLE assignments -- an assignment given to the participant of a course, contains a project
(
    project_id    INTEGER                  NOT NULL REFERENCES projects ON DELETE CASCADE,
    course_id     INTEGER                  NOT NULL REFERENCES courses ON DELETE CASCADE,
    status        assignment_status        NOT NULL,
    solution_mode assignment_solution_mode NOT NULL,
    number        SMALLINT                 NOT NULL CHECK ( number >= 0),
    PRIMARY KEY (project_id, course_id)
);

CREATE TYPE correct AS ENUM ( -- if a question has been answered correctly
    'unknown',
    'correct',
    'false'
    );

CREATE TABLE answers -- time and content the participant has answered to a question, including corrects
(
    id                         INTEGER PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    course_id                  INTEGER   NOT NULL REFERENCES courses ON DELETE CASCADE,
    participant_id             INTEGER   NOT NULL REFERENCES participants ON DELETE CASCADE, -- TODO: without constraints?
    project_id                 INTEGER   NOT NULL REFERENCES projects ON DELETE CASCADE,
    task_number                SMALLINT  NOT NULL,
    question_number            SMALLINT  NOT NULL,
    created_at                 TIMESTAMP NOT NULL DEFAULT NOW(),
    answer                     VARCHAR   NOT NULL,
    is_correct_automatic       correct   NOT NULL DEFAULT 'unknown',
    is_correct_manual_approval correct   NOT NULL DEFAULT 'unknown',
    FOREIGN KEY (project_id, task_number, question_number) REFERENCES questions (project_id, task_number, number) ON DELETE CASCADE
);
